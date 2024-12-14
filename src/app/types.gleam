import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/json.{int, object, string, to_string}

pub type Context {
  Context(
    mpesa_shortcode: Int,
    mpesa_passkey: String,
    mpesa_consumer_key: String,
    mpesa_consumer_secret: String,
    mpesa_callback_url: String,
  )
}

pub type AccessToken {
  AccessToken(access_token: String, expires_in: String)
}

pub type StkBody {
  StkBody(amount: Int, phone_number: Int)
}

pub type StkPush {
  StkPush(
    business_shortcode: Int,
    password: String,
    timestamp: String,
    transaction_type: String,
    amount: Int,
    party_a: Int,
    party_b: Int,
    phone_number: Int,
    callback_url: String,
    account_reference: String,
    transaction_desc: String,
  )
}

pub type StkPushResponse {
  StkPushResponse(
    merchant_request_id: String,
    checkout_request_id: String,
    result_code: Int,
    result_desc: String,
    callback_metadata: CallbackMetadata,
  )
}

pub type CallbackMetadata {
  CallbackMetadata(item: List(Dict(String, Dynamic)))
}

pub type Item {
  Item(name: String, value: String)
}

pub fn decode_token() {
  dynamic.decode2(
    AccessToken,
    dynamic.field("access_token", dynamic.string),
    dynamic.field("expires_in", dynamic.string),
  )
}

pub fn decode_stk_body() {
  dynamic.decode2(
    StkBody,
    dynamic.field("amount", dynamic.int),
    dynamic.field("phone_number", dynamic.int),
  )
}

pub fn encode_stk_body(stk_push: StkPush) -> String {
  object([
    #("BusinessShortCode", int(stk_push.business_shortcode)),
    #("Password", string(stk_push.password)),
    #("Timestamp", string(stk_push.timestamp)),
    #("TransactionType", string(stk_push.transaction_type)),
    #("Amount", int(stk_push.amount)),
    #("PartyA", int(stk_push.party_a)),
    #("PartyB", int(stk_push.party_b)),
    #("PhoneNumber", int(stk_push.phone_number)),
    #("CallBackURL", string(stk_push.callback_url)),
    #("AccountReference", string(stk_push.account_reference)),
    #("TransactionDesc", string(stk_push.transaction_desc)),
  ])
  |> to_string()
}
