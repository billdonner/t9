//
//  aiconn.swift
//  t7
//
//  Created by bill donner on 12/10/23.
//

import Foundation

func callOpenAI(APIKey: String, 
                decoder:@escaping DecoderFunc,
                model:String,
                timeout:TimeInterval,
                maxtokens:Int,
                systemMessage: String,
                userMessage: String) async throws {
  let starttime = Date()
  let baseURL = "https://api.openai.com/v1/chat/completions"
  let headers = ["Authorization": "Bearer \(APIKey)","Content-Type":"application/json"]
  let parameters = [
    "model":model,
    "max_tokens": maxtokens,
    "temperature": 1,
    "messages": [
      ["role": "system", "content": systemMessage],
      ["role": "user", "content": userMessage]
    ]
  ] as [String : Any]
  
  let jsonData = try JSONSerialization.data(withJSONObject: parameters)
  
  var request = URLRequest(url: URL(string: baseURL)!)
  request.httpMethod = "POST"
  request.allHTTPHeaderFields = headers
  request.httpBody = jsonData
  request.timeoutInterval = timeout
  
  var s = ""
  let (data, _) = try await URLSession.shared.data(for:request)
  
  let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
  guard let choices = json?["choices"] as? [[String: Any]],  
          let firstChoice = choices.first,
        let message = firstChoice["message"] as? [String: Any],
          let content = message["content"] as? String
  else {
    let str = String(data:data,encoding: .utf8) ?? "fail"
    print ("*** Error unknown response from AI:")
    print(str)
    throw T9Errors.badResponseFromAI
  }
  do {
    // if content is not surrounded by adding them
    s = content
    if !content.hasPrefix("[") {
      s = "[" + s + "]"
    }
      try decoder(s,starttime,!firsttime)
  } catch {
    print("*** Error could not decode response from AI: \(error)")
    print(s)
    throw T9Errors.badResponseFromAI
  }
}


