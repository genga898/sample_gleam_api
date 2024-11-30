import app/router
import app/types.{Context}
import dot_env
import dot_env/env
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load

  let secret_key = wisp.random_string(64)
  let assert Ok(short_code) = env.get_int("MPESA_SHORT_CODE")
  let assert Ok(mpesa_passkey) = env.get_string("MPESA_PASSKEY")
  let assert Ok(mpesa_secret) = env.get_string("MPESA_CONSUMER_SECRET")
  let assert Ok(mpesa_key) = env.get_string("MPESA_CONSUMER_KEY")
  let assert Ok(mpesa_callback_url) = env.get_string("MPESA_CALLBACK_URL")

  let context =
    Context(
      short_code,
      mpesa_passkey,
      mpesa_key,
      mpesa_secret,
      mpesa_callback_url,
    )

  let handler = router.handle_request(_, context)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key)
    |> mist.new
    |> mist.port(7000)
    |> mist.start_http

  process.sleep_forever()
}
