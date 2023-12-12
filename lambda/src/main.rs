use lambda_http::{run, service_fn, Body, Error, Request, RequestExt};
use serde::{Deserialize,Serialize};
use lambda_runtime::LambdaEvent;
#[derive(Deserialize)]
struct MyRequest {
    image_64_encode: String,
}

#[derive(Serialize)]
struct Response {
    s3_url:String,
    process_id: String,
    msg: String,
}

async fn function_handler(event :LambdaEvent<MyRequest>) -> Result<Response,Error>{
    let image = event.payload.image_64_encode;
    let response = Response {
        s3_url: String::from("https://fake-app.s3.amazonaws.com/fakeimage"),
        process_id: String::from("1234567890"),
        msg: String::from("Successful upload"),
    };
    Ok(response)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        // disable printing the name of the module in every log line.
        .with_target(false)
        // disabling time is handy because CloudWatch will add the ingestion time.
        .without_time()
        .init();

    lambda_runtime::run(service_fn(function_handler)).await
}
