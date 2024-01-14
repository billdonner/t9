//
//  aiconn.swift
//  t7
//
//  Created by bill donner on 12/10/23.
//

import Foundation
import q20kshare

public func getAPIKey() throws -> String {
  var wooky:String = ""
//  let  looky = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
//  if let looky = looky { wooky = looky }
//  if wooky == "" {
    wooky = "/users/fs/openapi.key"
 // }
  let key = try String(contentsOfFile: wooky,encoding: .utf8)
 return   key.trimmingCharacters(in: .whitespacesAndNewlines)
}

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
  if model.hasPrefix("gpt-4-1106-preview") {
  //  parameters[ "response_format" ] = [ "type": "json_object"]
  }
  
  let jsonData = try JSONSerialization.data(withJSONObject: parameters)
  
  var request = URLRequest(url: URL(string: baseURL)!)
  request.httpMethod = "POST"
  request.allHTTPHeaderFields = headers
  request.httpBody = jsonData
  request.timeoutInterval = timeout
  
  var s = ""
  let (data, _) = try await URLSession.shared.data(for:request)
//  let ss = String(data:data,encoding: .utf8) ?? ""
//  print(ss)
  
  /**
   first process metrics and usage if we can
   */ 
   let usage = get_usage_metrics(data)
 
//  now on to errors and content
  
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
   var scontent = content.trimmingCharacters(in: .whitespacesAndNewlines)
    //if content has bullshit strip it
    if scontent.hasPrefix( "```json") {
      scontent.removeFirst(7)
    }
    //```]
    if scontent.hasSuffix( "```") {
      scontent.removeLast(3)
    }
    scontent = scontent.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // if content is not surrounded by brackets now adding them
    s = scontent
    if !scontent.hasPrefix("[") {
      s = "[" + s
    }
    if !scontent.hasSuffix("]") {
      s += "]"
    }
      try decoder(s,starttime,usage)
  } catch {
    print("*** Error could not decode response from AI: \(error)")
    print(s)
    throw T9Errors.badResponseFromAI
  }
}



func encodeStringForJSON(string: String) -> String {
  let escapedString = string.replacingOccurrences(of: "\"", with: "\\\"")
  return "\"\(escapedString)\""
}

public func dontCallTheAI(ctx:ChatContext, prompt: String) {
  print("\n>Deliberately not calling AI for prompt #\(ctx.tag):\n")
  print(prompt)
  //sleep(3)
}

public func callChatGPT( ctx:ChatContext,
                             prompt:String,
                             outputting: @escaping (String)->Void ,
                              wait:Bool = false ) throws
{
  ctx.prompt = encodeStringForJSON(string:prompt) // copy this away
 var request = URLRequest(url: ctx.apiURL)
 request.httpMethod = "POST"
 request.setValue("application/json", forHTTPHeaderField: "Content-Type")
 request.setValue("Bearer " + ctx.apiKey, forHTTPHeaderField: "Authorization")
 request.timeoutInterval = 240//yikes
 
 var respo:String = ""
 
 let parameters: [String: Any] = [
  
   "model": ctx.model,
   "max_tokens": 2000,
   "top_p": 1,
   "frequency_penalty": 0,
   "presence_penalty": 0,
   "temperature": 1.0,
   "messages"  : [["role": "system",
                   "content": "this is the system area"],
                 [  "role": "user",
                    "content": "\(prompt)"]]
 ]
  print(parameters)
  let x = try JSONSerialization.data(withJSONObject: parameters, options: [])
  request.httpBody  =  x

 if ctx.verbose {
   print("\n>Prompt #\(ctx.tag): \n\(prompt) \n\n>Awaiting response #\(ctx.tag) from AI.\n")
 }
 else {
   print("\n>Prompt #\(ctx.tag): Awaiting response from AI.\n")
 }
 
 let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
   guard let data = data, error == nil else {
     print("*** Network error communicating with AI ***")
     print(error?.localizedDescription ?? "Unknown error")
     ctx.networkGlitches += 1
     print("*** continuing ***\n")
     respo = " " // a hack to bust out of wait loop below
     return
   }
   do {
     let response = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
     respo  = response.choices.first?.text ?? "<<nothin>>"
     outputting(respo)
   }  catch {
     print ("*** Failed to decode response from AI ***\n",error)
     let str = String(decoding: data, as: UTF8.self)
     print (str)
     ctx.networkGlitches += 1
     print("*** NOT continuing ***\n")
     respo = " " // a hack to bust out of wait loop below
     //return
     exit(0)
   }
 }
 task.resume()
 // linger here if asked to wait
 if wait {
   var cycle = 0
   while true && respo == ""  {
     //print before we sleep
     if ctx.dots {print("\(cycle)",terminator: "")}
     cycle = (cycle+1) % 10
     for _ in 0..<10 {
       if respo != "" { break }
       sleep(1)
     }
 
   }
 }
}

  func handleAIResponse(ctx:ChatContext,cleaned: [String],jsonOut:FileHandle?,
                        itemHandler:ITEMHandler) {
    
    // check to make sure it's valid and write to output file
    for idx in 0..<cleaned.count {
      do {
        try itemHandler(ctx,cleaned [idx],jsonOut )
      }
      catch {
        print(">Pumper Could not decode \(error), \n>*** BAD JSON FOLLOWS ***\n\(cleaned[idx])\n>*** END BAD JSON ***\n")
        ctx.badJsonCount += 1
        print("*** continuing ***\n")
      }
    }
  }
  
  func callTheAI(ctx:ChatContext,
                 prompt: String,
                 jsonOut:FileHandle?,
                 cleaner:@escaping CLEANINGHandler,
                 itemHandler: @escaping ITEMHandler)  {
    // going to call the ai
    let start_time = Date()
    do {
      try callChatGPT(ctx:ctx,
                      prompt : prompt,
                      outputting:  { response in
        // process response from chatgpt
        let cleaned = cleaner(response)
        // if not good then pumpCount not incremented
        if cleaned.count == 0 {
          print("\n>AI Response #\(ctx.tag): no challenges  \n")
          return
        }
        handleAIResponse(ctx:ctx, cleaned:cleaned, jsonOut:jsonOut){ ctx,s,fh  in
          try itemHandler(ctx,s,fh )
        }
        
        ctx.pumpCount += cleaned.count  // this is the number items from
        let elapsed = Date().timeIntervalSince(start_time)
        print("\n>AI Response #\(ctx.tag): \(cleaned.count) challenges returned in \(elapsed) secs\n")
        if ctx.pumpCount >= ctx.max {  // so max limits the number of times we will successfully call chatgpt
         return // Pumper.exit()
        }
      }, wait:true)
      // did not throw
    } catch {
      // if callChapGPT throws we end up here and just print a message and continu3
      let elapsed = Date().timeIntervalSince(start_time)
      print("\n>AI Response #\(ctx.tag): ***ERROR \(error) no challenges returned in \(elapsed) secs\n")
    }
  }
public func pumpItUp(ctx:ChatContext,
                     templates: [String],
                     jsonOut:FileHandle,
                     justOnce:Bool,
                     cleaner:@escaping CLEANINGHandler,
                     itemHandler:@escaping ITEMHandler) throws {
  
  while ctx.pumpCount<ctx.max {
    // keep doing until we hit user defined limit
    for (idx,t) in templates.enumerated() {
      guard ctx.pumpCount < ctx.max else { throw PumpingErrors.reachedMaxLimit }
      let prompt0 = stripComments(source: String(t), commentStart: ctx.comments_pattern)
      if t.count > 0 {
        let prompt = standardSubstitutions(source:prompt0,stats:ctx)
        if prompt.count > 0 {
          ctx.global_index += 1
          ctx.tag = String(format:"%03d",ctx.global_index) +  "-\(ctx.pumpCount)" + "-\( ctx.badJsonCount)" + "-\(ctx.networkGlitches)"
          if ctx.dontcall {
            dontCallTheAI(ctx:ctx, prompt: prompt)
          } else {
            callTheAI(ctx: ctx, prompt: prompt,jsonOut:jsonOut, cleaner:cleaner,itemHandler: itemHandler)
          }
        }
      } else {
        print("Warning - empty template #\(idx)")
      }
    }// for
    if justOnce { throw PumpingErrors.reachedEndOfScript}
  }
  throw PumpingErrors.reachedMaxLimit
}
