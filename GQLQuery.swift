import Foundation
import Dispatch

final class GQLQuery {
    
	let name: String
    let perNodeCallback: ((GQLNode)->Bool)?

	private let rootElement: GQLScanning
	private let parent: GQLNode?
    
    init(name: String, rootElement: GQLScanning, parent: GQLNode? = nil, perNodeCallback: ((GQLNode)->Bool)? = nil) {
		self.rootElement = rootElement
		self.parent = parent
		self.name = name
        self.perNodeCallback = perNodeCallback
	}

    static func batching(_ name: String, fields: [GQLElement], idList: ContiguousArray<String>, batchSize: Int, perNodeCallback: ((GQLNode)->Bool)? = nil) -> [GQLQuery] {
		var list = idList
        var queries = [GQLQuery]()
		while !list.isEmpty {
            let segment = list.prefix(batchSize)
            list.removeFirst(segment.count)

            let batchGroup = GQLBatchGroup(templateGroup: GQLGroup(name: "items", fields: fields), idList: Array(segment), batchSize: batchSize)
            let query = GQLQuery(name: name, rootElement: batchGroup, perNodeCallback: perNodeCallback)
            queries.append(query)
		}
        return queries
	}
    
    private var rootQueryText: String {
        if let parentItem = parent {
            return "node(id: \"\(parentItem.id)\") { ... on \(parentItem.elementType) { " + rootElement.queryText + " } }"
        } else {
            return rootElement.queryText
        }
    }
    
    private var fragmentQueryText: String {
        var fragments = Set<GQLFragment>()
        rootElement.fragments.forEach {
            fragments.insert($0)
        }
        return fragments.map { $0.declaration }.joined(separator: " ")
    }
    
	private var queryText: String {
		return fragmentQueryText + " { " + rootQueryText + " rateLimit { limit cost remaining resetAt nodeCount } }"
	}

    private static let qlQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 2
        q.qualityOfService = .background
        return q
    }()

    func run(for url: String, authToken: String, attempt: Int, completion: @escaping (Error?, ApiStats?)->Void) {
        
        let Q = queryText
        if Settings.dumpAPIResponsesInConsole {
            DLog("\(self.logPrefix)Fetching: \(Q)")
        }

        let server = URL(string: url)!
		var r = URLRequest(url: server)
		r.httpMethod = "POST"
		r.httpBody = try! JSONEncoder().encode(["query": Q])
        r.setValue("bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let task = API.task(for: r) { info, response, error in

            func doneWithError(_ message: String, _ error: Error?, shouldRetry: Bool, apiStats: ApiStats?) {
                DLog("\(self.logPrefix) Error: \(message)")
                if shouldRetry && attempt > 0 {
                    DLog("\(self.logPrefix) Pausing for retry, attempt \(attempt)")
                    Thread.sleep(forTimeInterval: 2)
                    self.run(for: url, authToken: authToken, attempt: attempt - 1, completion: completion)
                } else {
                    let e = error ?? NSError(domain: "com.housetrip.Trailer.gqlError", code: 1, userInfo: [NSLocalizedDescriptionKey: "message"])
                    completion(e, apiStats)
                }
            }

			guard let info = info, let json = (try? JSONSerialization.jsonObject(with: info, options: [])) as? [AnyHashable : Any] else {
                
                if let error = error {
                    doneWithError("Network error: \(error.localizedDescription)", error, shouldRetry: false, apiStats: nil)
                } else {
                    doneWithError("No JSON in response", nil, shouldRetry: false, apiStats: nil)
                }
                return
            }

            if Settings.dumpAPIResponsesInConsole {
                DLog("API data from %@: %@", url, String(bytes: info, encoding: .utf8))
            }
            
            let apiStats = ApiStats.fromV4(json: json["data"] as? [AnyHashable : Any])
            if let s = apiStats {
                DLog("\(self.logPrefix)Received page (Cost: \(s.cost), Remaining: \(s.remaining)/\(s.limit) - Node Count: \(s.nodeCount))")
            } else {
                DLog("\(self.logPrefix)Received page (No stats)")
            }
            
            let allData = json["data"] as? [AnyHashable : Any]
            guard let data = (self.parent == nil) ? allData : allData?["node"] as? [AnyHashable : Any] else {
                let code = (response as? HTTPURLResponse)?.statusCode
                let shouldRetry = code == 403 || code == 502 || code == 503 // pause to retry in case of throttle or ongoing GH deployment
                if let errors = json["errors"] as? [[AnyHashable:Any]] {
                    let msg = errors.first?["message"] as? String ?? "Unspecified server error: \(json)"
                    doneWithError("Failed with error: '\(msg)'", nil, shouldRetry: shouldRetry, apiStats: apiStats)
                } else {
                    let msg = json["message"] as? String ?? "Unspecified server error: \(json)"
                    doneWithError("Failed with error: '\(msg)'", nil, shouldRetry: shouldRetry, apiStats: apiStats)
                }
                return
            }
                        
            let r = self.rootElement
            guard let topData = data[r.name] else {
                doneWithError("No data in JSON", nil, shouldRetry: false, apiStats: apiStats)
                return
            }
            
            let extraQueries = r.scan(query: self, pageData: topData, parent: self.parent)
            if extraQueries.isEmpty {
                completion(nil, apiStats)
            } else {
                DLog("\(self.logPrefix)Needs more page data")
                ApiServer.runQueries(queries: extraQueries, on: url, token: authToken, completion: completion)
            }
        }
        
        let capturedName = name
        API.submitDataTask(task, on: GQLQuery.qlQueue) {
            DispatchQueue.main.async {
                API.currentOperationName = capturedName
            }
        }
	}
    
    var logPrefix: String {
        return "(GQL '\(name)') "
    }    
}
