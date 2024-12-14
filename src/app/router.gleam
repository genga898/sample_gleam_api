import app/middleware.{get_auth_token, middleware}
import app/types.{type Context}
import decode/zero
import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json.{int, string}
import gleam/result
import gleam/string
import gleam/string_tree
import tempo/datetime
import wisp.{type Request, type Response}

pub fn handle_request(req: wisp.Request, ctx: Context) -> wisp.Response {
  use req <- middleware(req)
  let auth_token = get_auth_token(ctx)

  case wisp.path_segments(req) {
    [] -> home(req)
    ["stk"] -> stkpush(req, auth_token, ctx)
    ["callback-url-path"] -> callback_url_path(req)
    _ -> wisp.not_found()
  }
}

pub fn home(req: Request) -> Response {
  use <- wisp.require_method(req, http.Get)
  json.object([#("Hello", string("World"))])
  |> json.to_string_tree
  |> wisp.json_response(200)
}

pub fn stkpush(req: Request, bearer_token: String, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  use <- wisp.require_content_type(req, "application/json")
  use content <- wisp.require_json(req)

  let content_decoder = {
    use amount <- zero.field("amount", zero.int)
    use phone_no <- zero.field("phone_number", zero.int)
    zero.success(types.StkBody(amount, phone_no))
  }
  let content_result =
    zero.run(content, content_decoder) |> result.unwrap(types.StkBody(0, 0))

  let timestamp = datetime.now_local() |> datetime.format("YYYYMMDDHHmmss")
  let token =
    string.concat([
      int.to_string(ctx.mpesa_shortcode),
      ctx.mpesa_passkey,
      timestamp,
    ])

  let auth_key = bit_array.base64_encode(<<token:utf8>>, True)
  let callback_url =
    string.concat([ctx.mpesa_callback_url, "/callback-url-path"])

  let password = auth_key
  let contact =
    int.parse("254" <> int.to_string(content_result.phone_number))
    |> result.unwrap(0)
  let url_path = "https://sandbox.safaricom.co.ke"
  let stk_push_body =
    types.StkPush(
      ctx.mpesa_shortcode,
      password,
      timestamp,
      "CustomerPayBillOnline",
      content_result.amount,
      contact,
      ctx.mpesa_shortcode,
      contact,
      callback_url,
      "Test",
      "Test",
    )
  let body = types.encode_stk_body(stk_push_body)
  let assert Ok(request_url) =
    request.to(url_path <> "/mpesa/stkpush/v1/processrequest")
  let stk_push_requests =
    request.prepend_header(request_url, "content-type", "application/json")
    |> request.set_header("authorization", "Bearer " <> bearer_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  let api_response = httpc.send(stk_push_requests)
  case api_response {
    Ok(rep) -> {
      wisp.json_response(string_tree.from_string(rep.body), rep.status)
    }
    _ -> {
      json.object([#("Error", json.string("Network error"))])
      |> json.to_string_tree
      |> wisp.json_response(502)
    }
  }
}

pub fn callback_url_path(req: Request) -> Response {
  use <- wisp.require_method(req, http.Post)
  use <- wisp.require_content_type(req, "application/json")
  use content <- wisp.require_json(req)
  io.debug(content)

  let metadata_decoder = {
    use item <- zero.field(
      "Item",
      zero.list(zero.dict(zero.string, zero.dynamic)),
    )
    zero.success(types.CallbackMetadata(item))
  }

  let callback_decoder = {
    use merchant_req_id <- zero.field("MerchantRequestID", zero.string)
    use checkout_req_id <- zero.field("CheckoutRequestID", zero.string)
    use result_code <- zero.field("ResultCode", zero.int)
    use result_desc <- zero.field("ResultDesc", zero.string)
    use callback_metadata <- zero.optional_field(
      "CallbackMetadata",
      types.CallbackMetadata([]),
      metadata_decoder,
    )

    zero.success(types.StkPushResponse(
      merchant_req_id,
      checkout_req_id,
      result_code,
      result_desc,
      callback_metadata,
    ))
  }

  let decoder = zero.at(["Body", "stkCallback"], callback_decoder)
  let stk_resp =
    zero.run(content, decoder)
    |> result.unwrap(types.StkPushResponse(
      "",
      "",
      9999,
      "",
      types.CallbackMetadata([]),
    ))

  case stk_resp.result_code {
    0 -> {
      io.debug(stk_resp)
      wisp.ok()
    }
    1032 -> {
      io.debug(stk_resp)
      json.object([#("Ok", json.string(stk_resp.result_desc))])
      |> json.to_string_tree
      |> wisp.json_response(200)
    }
    _ -> wisp.ok()
  }
}
