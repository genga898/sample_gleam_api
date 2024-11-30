import app/types.{type Context, decode_token}
import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result
import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.require_content_type(req, "application/json")
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}

pub fn get_auth_token(ctx: Context) -> String {
  let token = ctx.mpesa_consumer_key <> ":" <> ctx.mpesa_consumer_secret

  let auth_key = bit_array.base64_encode(<<token:utf8>>, True)
  let url_path = "https://sandbox.safaricom.co.ke"
  let assert Ok(target_req) =
    request.to(url_path <> "/oauth/v1/generate?grant_type=client_credentials")

  let requests =
    request.prepend_header(target_req, "authorization", "Basic " <> auth_key)
    |> request.set_method(http.Get)

  let api_resp =
    httpc.send(requests) |> result.replace_error("Unable to authenticate")

  case api_resp {
    Ok(t) -> {
      case json.decode(from: t.body, using: decode_token()) {
        Ok(resp) -> resp.access_token
        Error(_err) -> "Error"
      }
    }
    Error(err) -> err
  }
}
