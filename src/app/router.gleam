import app/middleware.{get_auth_token, middleware}
import app/types.{type Context}
import birl
import dateformat
import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json.{int, string}
import gleam/string
import gleam/string_tree
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

  wisp.json_response(string_tree.from_string("{\"Hello\": \"World\"}"), 200)
}

pub fn stkpush(req: Request, bearer_token: String, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)

  let assert Ok(timestamp) = dateformat.format("YYYYMMDDHHmmss", birl.now())
  io.debug
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
  let amount = 1
  let phone_no = 254_768_188_328
  let url_path = "https://sandbox.safaricom.co.ke"
  let stk_push_body =
    types.StkPush(
      ctx.mpesa_shortcode,
      password,
      timestamp,
      "CustomerPayBillOnline",
      amount,
      phone_no,
      ctx.mpesa_shortcode,
      phone_no,
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
    Error(_err) -> {
      json.object([#("Error", json.string("Response error"))])
      |> json.to_string_tree
      |> wisp.json_response(400)
    }
  }
}

pub fn callback_url_path(req: Request) -> Response {
  use <- wisp.require_method(req, http.Post)
  use <- wisp.require_content_type(req, "application/json")
  use content <- wisp.require_json(req)
  io.debug(content)
  let stk_response = content |> types.decode_stk_response()

  case stk_response {
    Ok(t) -> {
      case t.response_code {
        0 ->
          json.object([
            #("MerchantRequestID", string(t.merchant_request_id)),
            #("CheckoutRequestID", string(t.checkout_request_id)),
            #("ResponseCode", int(t.response_code)),
            #("ResponseDescription", string(t.response_description)),
            #("CustomerMessage", string(t.customer_message)),
          ])
          |> json.to_string_tree
          |> io.debug
          |> wisp.json_response(200)

        _ ->
          wisp.json_response(
            string_tree.from_string(t.response_description),
            t.response_code,
          )
      }
    }
    Error(_err) -> wisp.json_response(string_tree.from_string("Error"), 400)
  }
}
