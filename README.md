# StubServer

## Description

**StubServer** is a Simple stub class for your network request.

## Installation

Clone this repository and import `StubServer.swift` inside Xcode (drag & drop).

## Useage

### Basic Example

```
let server = StubServer()

server.get("/api") { request, response in
    response.end("Hello, World!")
}

server.run()
```

### Advanced Example

```
// Specified the host
let server = StubServer(host: "example.com")

server.get("/search") { request, response in

    // Get query parameter
    if let q = request.queryParams["q"] where q == "pokemon" {
        response.end("Pikachu")
    } else {
    	response.end("Query not found")
    }
}

server.post("/form") { request, response in
    response.send("Hello")
    
    // Get HTTP body
    if let body = request.body, q = body["q"] as? String where q == "pokemon" {
        response.send("Pikachu")
    }

    response.end("!")
}

server.all("/deny") { request, response in 
	response.status(404).end()
}

server.run()
```

## Using with NSURLSessionConfiguration

You need to set stub protocol to `protocolClasses` when using NSURLSessionConfiguration.

```
let url = NSURL(string: "http://example.com/api")

let config = NSURLSessionConfiguration.defaultSessionConfiguration()
config.protocolClasses = [StubServer.protocolClass]

let session = NSURLSession(configuration: config)
```
