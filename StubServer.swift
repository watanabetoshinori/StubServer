//
//  StubServer.swift
//  StubServer
//
//  Created by Watanabe Toshinori on 7/24/16.
//

import UIKit

class StubServer {
    
    // Server Handler

    typealias ResnponseHandler = (request: StubServerRequest, response: StubServerResponse) -> Void
    
    // Stub Handlers

    typealias StartedResponseHandler = (NSURLResponse) -> Void
    
    typealias SendResponseHandler = (NSData) -> Void
    
    typealias FinishedResponseHandler = () -> Void

    typealias ErrorResponseHandler = (NSError) -> Void

    // Properties
    
    private static var token: dispatch_once_t = 0

    private var host: String?

    private var port: Int?
    
    private var stubs = [Stub]()

    static let protocolClass: NSURLProtocol.Type = {
        return StubProtocol.self
    }()

    // MARK: - Initialize
    
    convenience init(host: String) {
        self.init()
        self.host = host
    }

    convenience init(host: String, port: Int) {
        self.init()
        self.host = host
        self.port = port
    }
    
    // MARK: - HTTP methods

    func all(path: String? = nil, handler: ResnponseHandler) {
        addStub("", path: path, handler: handler)
    }

    func get(path: String? = nil, handler: ResnponseHandler) {
        addStub("get", path: path, handler: handler)
    }
    
    func post(path: String? = nil, handler: ResnponseHandler) {
        addStub("post", path: path, handler: handler)
    }
    
    func put(path: String? = nil, handler: ResnponseHandler) {
        addStub("put", path: path, handler: handler)
    }
    
    func delete(path: String? = nil, handler: ResnponseHandler) {
        addStub("delete", path: path, handler: handler)
    }
    
    // MARK: - Run the Stub Server

    func run() {
        dispatch_once(&StubServer.token) {
            NSURLProtocol.registerClass(StubProtocol)
        }
        
        StubProtocol.stubs += stubs
    }
    
    // MARK: - Create Stub
    
    private func addStub(method: String, path: String?, handler: ResnponseHandler) {
        let stub = Stub(
            condition: { (request) -> Bool in
                // Method
                if let requestMethod = request.HTTPMethod?.lowercaseString where method.isEmpty == false && requestMethod != method {
                    return false
                }
                
                // Host
                if let requestHost = request.URL?.host, host = self.host where requestHost != host {
                    return false
                }
                
                // Port
                if let requestPort = request.URL?.port?.integerValue, port = self.port where requestPort != port {
                    return false
                }
                
                // Path
                if let path = path {
                    if let requestPath = request.URL?.path where requestPath == path {
                        return true
                    }
                } else {
                    return true
                }

                return false
            },
            response: { (request, started, send, finished, error) in

                let request = StubServerRequest(request: request)

                let response = StubServerResponse(URL: request.URL, started: started, send: send, finished: finished, error: error)

                handler(request: request, response: response)
            }
        )
        
        stubs.append(stub)
    }
    
    // MARK: - Stub
    
    private struct Stub {

        let condition: (NSURLRequest) -> Bool
        
        let response: (NSURLRequest, StartedResponseHandler, SendResponseHandler, FinishedResponseHandler, ErrorResponseHandler) -> Void
        
    }

    // MARK: - Stub Protocol

    private class StubProtocol : NSURLProtocol {
        
        private static var stubs = [Stub]()
        
        // MARK: - NSURLProtocol methods
        
        override var cachedResponse: NSCachedURLResponse? { return nil }
        
        override init(request: NSURLRequest, cachedResponse: NSCachedURLResponse?, client: NSURLProtocolClient?) {
            super.init(request: request, cachedResponse: nil, client: client)
        }
        
        override class func canInitWithRequest(request: NSURLRequest) -> Bool {
            return stubs.filter({ return $0.condition(request) }).count > 0
        }
        
        override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
            return request
        }
        
        override func startLoading() {
            let stub = StubProtocol.stubs.filter({ return $0.condition(request) }).first!
            
            stub.response(request,
                          { [weak self] (URLResponse) in
                            // Start
                            guard let weakSelf = self else {
                                return
                            }
                            
                            weakSelf.client?.URLProtocol(weakSelf, didReceiveResponse: URLResponse, cacheStoragePolicy: .NotAllowed)
                },
                          { [weak self] (data) in
                            // Send
                            guard let weakSelf = self else {
                                return
                            }

                            weakSelf.client?.URLProtocol(weakSelf, didLoadData: data)
                },
                          { [weak self] () in
                            // Finished
                            
                            guard let weakSelf = self else {
                                return
                            }
                            
                            weakSelf.client?.URLProtocolDidFinishLoading(weakSelf)
                },
                          { [weak self] (error) in
                            // Error

                            guard let weakSelf = self else {
                                return
                            }
                            
                            weakSelf.client?.URLProtocol(weakSelf, didFailWithError: error)
            })
        }
        
        override func stopLoading() {}
    }

    // MARK: - Content Type

    enum ContentType {
        case text
        case html
        case json
        case urlEncoded
        case custom(type: String)

        var headerString: String {
            switch self {
            case .text:
                return "text/plain"
            case .json:
                return "application/json"
            case .custom(let type):
                return type
            case .html:
                fallthrough
            default:
                return "text/html"
            }
        }

        static func contentTypeWithHeaderString(headerString: String) -> ContentType {
            switch headerString {
            case "application/x-www-form-urlencoded":
                return .urlEncoded
            case "application/json", "text/json":
                return .json
            case "text/plain":
                return .text
            case "text/html":
                return .html
            default:
                return .custom(type: headerString)
            }
        }

        static func contentTypeWithBasicString(string: String) -> ContentType {
            switch string.lowercaseString {
            case "txt", "text":
                return .text
            case "htm", "html":
                return .html
            case "json":
                return .json
            default:
                return .custom(type: string)
            }
        }
    }

    // MARK: - Stub Server Request

    class StubServerRequest {
        
        class Body: Equatable, CustomStringConvertible, StringLiteralConvertible {
            
            private var string: String?
            
            private var dictionary: [String: AnyObject?]?
            
            // MARK: - Initializers
            
            init(dictionary value: [String: AnyObject?]) {
                self.dictionary = value
            }
            
            required init(stringLiteral value: StringLiteralType) {
                string = "\(value)"
            }
            
            required init(extendedGraphemeClusterLiteral value: String) {
                string = value
            }
            
            required init(unicodeScalarLiteral value: String) {
                string = value
            }
            
            // MARK: - Subscript
            
            subscript(key: String) -> AnyObject? {
                if let dictionary = dictionary, value = dictionary[key] {
                    return value
                }
                return nil
            }
            
            // MARK: - CustomStringConvertible
            
            var description: String {
                return dictionary?.description ?? string ?? ""
            }
        }

        private var URLRequest: NSURLRequest!

        private let components: NSURLComponents!

        var URL: NSURL {
            return URLRequest.URL!
        }

        var scheme: String {
            return components.scheme!
        }

        var host: String {
            return components.host!
        }

        var port: Int? {
            if let port = components.port {
                return Int(port)
            }
            return nil
        }

        var path: String? {
            return components.path
        }

        var query: String? {
            return components.query
        }

        var queryParams: [String: String?] = [:]

        var body: Body?

        // MARK: - Initializer

        init(request: NSURLRequest) {
            guard let URL = request.URL else {
                fatalError()
            }

            URLRequest = request

            components = NSURLComponents(string: URL.absoluteString ?? "")

            parseQuery()

            parseBody()
        }

        // MARK: - Parse Query and Body

        private func parseQuery() {
            components.queryItems?.forEach({ (item) in
                queryParams[item.name] = item.value
            })
        }

        private func parseBody() {

            let data: NSData = {
                // Read data from HTTP Body
                if let data = URLRequest.HTTPBody {
                    return data
                }

                // Read data from HTTP Body stream
                if let stream = URLRequest.HTTPBodyStream {
                    let data = NSMutableData()
                    stream.open()
                    while stream.hasBytesAvailable {
                        var buffer = [UInt8](count: 512, repeatedValue: 0)
                        let len = stream.read(&buffer, maxLength: buffer.count)
                        data.appendBytes(buffer, length: len)
                    }
                    stream.close()

                    return data
                }

                return NSData()
            }()

            if data.length == 0 {
                return
            }

            var contentType = ""

            if let headers = URLRequest.allHTTPHeaderFields, contentTypeString = headers["Content-Type"] {
                contentType = contentTypeString

                if let parameterStart = contentType.rangeOfString(";") {
                    contentType = contentType.substringToIndex(parameterStart.startIndex)
                }
            }

            switch ContentType.contentTypeWithHeaderString(contentType) {
            case .urlEncoded:
                if let bodyAsString = String(data: data, encoding: NSUTF8StringEncoding) {
                    let bodyAsArray = bodyAsString.componentsSeparatedByString("&")

                    var parameters: [String: AnyObject?] = [:]

                    bodyAsArray.forEach({ (element) in
                        let elementPair = element.componentsSeparatedByString("=")

                        if elementPair.count == 2 {
                            parameters[elementPair[0]] = elementPair[1]
                        } else {
                            parameters[element] = nil
                        }
                    })
                    
                    body = Body(dictionary: parameters)
                }
            case .json:
                do {
                    if let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: AnyObject] {
                        body = Body(dictionary: json)
                    }
                } catch let error as NSError {
                    print(error)
                }
            default:
                if let string = String(data: data, encoding: NSUTF8StringEncoding) {
                    body = Body(stringLiteral: string)
                }
            }
        }

    }

    // MARK: - Stub Server Response

    class StubServerResponse {

        private var status = 200

        private var headers: [String: String]?

        private var data: NSMutableData?

        private var charset = "utf8"

        private var type: ContentType = .html

        private var URL: NSURL
        
        private var startedHandler: StartedResponseHandler?
        
        private var sendHandler: SendResponseHandler?
        
        private var finishedHandler: FinishedResponseHandler?
        
        private var errorHandler: ErrorResponseHandler?
        
        private var isSendResponse = false

        // MARK: - Initializing

        init(URL: NSURL, started: StartedResponseHandler, send: SendResponseHandler, finished: FinishedResponseHandler, error: ErrorResponseHandler) {
            self.URL = URL
            self.startedHandler = started
            self.sendHandler = send
            self.finishedHandler = finished
            self.errorHandler = error
        }

        // MARK: - Content-Type

        func type(type: ContentType) -> StubServerResponse {
            self.type = type

            return self
        }

        func type(type: String) -> StubServerResponse {
            return self.type(.contentTypeWithBasicString(type))
        }

        // MARK: - HTTP Status

        func status(status: Int) -> StubServerResponse {
            self.status = status
            return self
        }

        // MARK: - HTTP headers
        
        func headers(headers: [String: String]) -> StubServerResponse {
            self.headers = headers
            
            return self
        }
        
        // MARK: - HTTP Body
        
        func send(data: NSData) -> StubServerResponse {

            sendURLResponse()

            sendHandler?(data)
            
            return self
        }
        
        func send(string: String) -> StubServerResponse {
            if let data = string.dataUsingEncoding(NSUTF8StringEncoding) {
                return send(data)
            }
            
            return self
        }
        
        func send(json: AnyObject) -> StubServerResponse {
            type(.json)
            
            do {
                let data = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions())
                return send(data)
                
            } catch let error as NSError {
                errorHandler?(error)
            }
            
            return self
        }

        // MARK: - End of response

        func end() {
            sendURLResponse()
            
            finishedHandler?()

            // free all handlers
            startedHandler = nil
            sendHandler = nil
            finishedHandler = nil
            errorHandler = nil
        }

        func end(data: NSData) {
            send(data)
            end()
        }

        func end(string: String) {
            send(string)
            end()
        }

        func end(json: AnyObject) {
            send(json)
            end()
        }
        
        // MARK: - Error response
        
        func error(error: NSError) {
            sendURLResponse()
            
            errorHandler?(error)
        }

        // MARK: - Creating URL Response
        
        private func sendURLResponse() {
            if isSendResponse == false {
                isSendResponse = true
                
                // Appends content-type if not set
                if var headers = headers where headers["Content-Type"] == nil {
                    self.headers!["Content-Type"] = "\(type.headerString); charset=\(charset)"
                } else {
                    self.headers = ["Content-Type": "\(type.headerString); charset=\(charset)"]
                }
                
                if let URLResponse = NSHTTPURLResponse(URL: URL, statusCode: status, HTTPVersion: "HTTP/1.1", headerFields: headers) {
                    startedHandler?(URLResponse)
                } else {
                    let error = NSError(domain: NSInternalInconsistencyException, code: 0, userInfo: [ NSLocalizedDescriptionKey: "Failed to prepare response."] )
                    errorHandler?(error)
                }
            }
        }
    }
    
}

func ==(lhs: StubServer.StubServerRequest.Body, rhs: StubServer.StubServerRequest.Body) -> Bool {
    return lhs.description == rhs.description
}
