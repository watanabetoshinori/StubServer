//
//  StubServerTest.swift
//  StubServerTest
//
//  Created by Watanabe Toshinori on 7/24/16.
//
//

import XCTest

class StubServerTest: XCTestCase {
    
    override func setUp() {
        super.setUp()

        let server = StubServer()
        
        // String
        server.get("/string") { request, response in
            response.end("Hello, World!")
        }

        // Strings
        server.get("/strings") { request, response in
            response.send("I got a Pikachu!\n")
            response.send("I got a Pikachu!\n")
            response.send("I got a Pikachu!\n")
            response.send("I got a Pikachu!\n")
            response.send("I got a Pikachu!\n")
            response.end()
        }
        
        // JSON
        server.get("/JSON") { request, response in
            response.end(["string": "John", "num": 1, "bool": true])
        }

        // Not Found
        server.get("/NotFound") { request, response in
            response.status(404).end()
        }
        
        // Change response by query
        server.get("/query") { request, response in
            if let q = request.queryParams["q"] where q == "pokemon" {
                response.end("pikachu")
                return
            }

            response.end("Query not found")
        }

        // Change response by body (string)
        server.post("/body/string") { request, response in
            if let body = request.body where body == "pokemon" {
                response.end("pikachu")
                return
            }
            
            response.end("Body not found")
        }

        // Change response by body (urlencoded/json)
        server.post("/body/urlencoded") { request, response in
            if let body = request.body, q = body["q"] as? String where q == "pokemon" {
                response.end("pikachu")
                return
            }
            
            response.end("Body not found")
        }

        server.run()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testString() {
        let expectaion = expectationWithDescription("Received response.")

        let task = NSURLSession.sharedSession().dataTaskWithRequest(NSURLRequest(URL: NSURL(string: "http://localhost/string")!)) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            guard let response = response as? NSHTTPURLResponse else {
                XCTFail("Invalid response.")
                return
            }
            
            XCTAssertEqual(response.statusCode, 200)

            guard let allHeaderFields = response.allHeaderFields as? [String: String]  else {
                XCTFail("Invalid header fields.")
                return
            }
            XCTAssertEqual(allHeaderFields, ["Content-Type": "text/html; charset=utf8"])
            
            let string = String(data: data!, encoding: NSUTF8StringEncoding)
            XCTAssertEqual(string, "Hello, World!")
            
            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }

    func testStrings() {
        let expectaion = expectationWithDescription("Received response.")
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(NSURLRequest(URL: NSURL(string: "http://localhost/strings")!)) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            let string = String(data: data!, encoding: NSUTF8StringEncoding)
            XCTAssertEqual(string, "I got a Pikachu!\nI got a Pikachu!\nI got a Pikachu!\nI got a Pikachu!\nI got a Pikachu!\n")
            
            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }
    
    func testJSON() {
        let expectaion = expectationWithDescription("Received response.")
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(NSURLRequest(URL: NSURL(string: "http://localhost/JSON")!)) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            guard let response = response as? NSHTTPURLResponse else {
                XCTFail("Invalid response.")
                return
            }
            
            XCTAssertEqual(response.statusCode, 200)

            guard let allHeaderFields = response.allHeaderFields as? [String: String]  else {
                XCTFail("Invalid header fields.")
                return
            }
            XCTAssertEqual(allHeaderFields, ["Content-Type": "application/json; charset=utf8"])
            
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
                
                guard let dict = json as? [String: NSObject] else {
                    XCTFail("Invalid JSON format.")
                    return
                }
                
                XCTAssertEqual(dict, ["string": "John", "num": 1, "bool": true])
                
            } catch {
                XCTFail("Failed to convert JSON.")
            }
            
            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }
    
    func testNotFound() {
        let expectaion = expectationWithDescription("Received response.")
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(NSURLRequest(URL: NSURL(string: "http://localhost/NotFound")!)) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)   // 0 byte data
            XCTAssertNil(error)
            
            guard let response = response as? NSHTTPURLResponse else {
                XCTFail("Invalid response.")
                return
            }
            
            XCTAssertEqual(response.statusCode, 404)

            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }

    func testQuery() {
        let expectaion = expectationWithDescription("Received response.")
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(NSURLRequest(URL: NSURL(string: "http://localhost/query?q=pokemon")!)) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            let string = String(data: data!, encoding: NSUTF8StringEncoding)

            XCTAssertEqual(string, "pikachu")

            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }

    func testNoQuery() {
        let expectaion = expectationWithDescription("Received response.")
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(NSURLRequest(URL: NSURL(string: "http://localhost/query")!)) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            let string = String(data: data!, encoding: NSUTF8StringEncoding)
            
            XCTAssertEqual(string, "Query not found")

            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }
    
    func testBodyString() {
        let expectaion = expectationWithDescription("Received response.")
        
        let request = NSMutableURLRequest(URL: NSURL(string: "http://localhost/body/string")!)
        request.addValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.HTTPMethod = "POST"
        request.HTTPBody = "pokemon".dataUsingEncoding(NSUTF8StringEncoding)
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)

            let string = String(data: data!, encoding: NSUTF8StringEncoding)
            
            XCTAssertEqual(string, "pikachu")

            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }
    
    func testBodyURLEncoded() {
        let expectaion = expectationWithDescription("Received response.")
        
        let request = NSMutableURLRequest(URL: NSURL(string: "http://localhost/body/urlencoded")!)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPMethod = "POST"
        request.HTTPBody = "q=pokemon".dataUsingEncoding(NSUTF8StringEncoding)
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            let string = String(data: data!, encoding: NSUTF8StringEncoding)
            
            XCTAssertEqual(string, "pikachu")

            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }
    
    func testBodyJSON() {
        let expectaion = expectationWithDescription("Received response.")
        
        let request = NSMutableURLRequest(URL: NSURL(string: "http://localhost/body/urlencoded")!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.HTTPMethod = "POST"
        request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(["q": "pokemon"], options: .PrettyPrinted)
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) -> Void in
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            
            let string = String(data: data!, encoding: NSUTF8StringEncoding)
            
            print(": \(string)")
            
            XCTAssertEqual(string, "pikachu")

            expectaion.fulfill()
        }
        task.resume()
        
        waitForExpectationsWithTimeout(3) { (error) in
            print(error)
        }
    }

}
