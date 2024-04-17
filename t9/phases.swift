//
//  phases.swift
//  t7
//
//  Created by bill donner on 12/9/23.
//

import Foundation
import q20kshare
//(String(format:"%4.2f",Date().timeIntervalSince(startTime)))
func showStats(_ jobno: String) {
  let succrate:Int = totalJobs == 0 ? 100 : succesfullJobs*100/totalJobs
  let totalCostSoFar = computeTotalCost(completionTokenCount: completionTokens, promptTokenCount: promptTokens, model: gmodel)
  let d = displayAsDollarAmount(totalCostSoFar)
  print("\n=== \(Date()) Job(\(totalJobs)) \(jobno) \(gmodel),tmo=\(Int(gtimeout)),maxt=\(gmaxtokens),p=\(totalPumped),r=\(totalRepaired),ct=\(completionTokens),pt=\(promptTokens),succ=\(succrate)%, \(d) ===")
}

func displayAsDollarAmount(_ value: Double) -> String {
  let numberFormatter = NumberFormatter()
  numberFormatter.numberStyle = .currency
  numberFormatter.currencySymbol = "$"
  
  if let formattedString = numberFormatter.string(from: NSNumber(value: value)) {
    return formattedString
  } else {
    return ""
  }
}

func pumpPhase(_ userMessage:String) async  throws{
  print ("pumping...\(userMessage)")
  try await callAI(msg1:systemMessage,
                   msg2:userMessage,
                   decoder:decodePumpingArray )
}
func validationPhase() async  throws {
  print("validating...")
  try await callAI(msg1:valsysMessage,
                   msg2:qmeBuf,
                   decoder:decodeValidationResponse )
}
func repairPhase() async throws{
  print("repairing... ")
  try await callAI(msg1:repsysMessage,msg2:qmeBuf,
                   decoder:decodeQuestionsArray )
}
func revalidationPhase() async throws {
  print("revalidating...")
  try await callAI(msg1:valsysMessage,
                   msg2:qmeBuf,
                   decoder:decodeReValidationResponse )
}

enum Phases:Int {
  case pumping
  case validating
  case repairing
  case revalidating
  
  
  static func perform(_ performPhases:[Bool],jobno:String,msg:String) async throws {
    do {
      let message = msg.trimmingCharacters(in: .whitespacesAndNewlines)
      if message != "" {
          showStats(jobno)
        totalJobs += 1
        if performPhases[0] {
          try await pumpPhase(msg)}
        else {print ("Skipping pumpPhase")}
        if performPhases[1] {
          try await validationPhase()}
        else {
          // print ("Skipping validationPhase")
        }
        if performPhases[2] {
          try await repairPhase()}
        else {print ("Skipping repairPhase")}
        if performPhases[3] {
          try await revalidationPhase()}
        else {//print ("Skipping revalidationPhase")
        }
        succesfullJobs += 1
      }
    }
    catch {
      print("\n===******** Cancelling Job \(jobno) : \(error) ***********===\n")
    }
  }
}

// Function to call the OpenAI API

fileprivate func decodeValidationResponse(_ content: String,_ started:Date, _ usage:Usage?) throws {
  let elapsed = String(format:"%4.2f",Date().timeIntervalSince(started))
  print(">AI validation response \(content.count) bytes in \(elapsed) secs \n\(content)")
  if let validatedHandle = validatedHandle {
    validatedHandle.write(content.data(using:.utf8)!)
  }
}
fileprivate func decodeReValidationResponse(_ content: String,_ started:Date, _ usage:Usage?) throws {
  let elapsed = String(format:"%4.2f",Date().timeIntervalSince(started))
  print(">AI revalidation response \(content.count) bytes in \(elapsed) secs \n\(content)")
  if let revalidatedHandle = revalidatedHandle {
    revalidatedHandle.write(content.data(using:.utf8)!)
  }
}
func getFileNameAndExtension(from filePath: String) -> (String,String, String) {
  let url = URL(fileURLWithPath: filePath)
  let lastPathComponent = url.deletingPathExtension().lastPathComponent
  let pathExtension = url.pathExtension
  let frontPath = filePath.dropLast(lastPathComponent.count + pathExtension.count+1)
  return (String(frontPath),lastPathComponent, pathExtension)
}
fileprivate func decodeQuestionsArray(_ content: String,_ started:Date,_  usage:Usage?) throws {
  totalTokens += usage?.total_tokens ?? 0
  completionTokens += usage?.completion_tokens ?? 0
  promptTokens += usage?.prompt_tokens ?? 0
  if gverbose {print("\(content)")}
  let lowercontent  = rewriteJSON( content) ?? "FAIL"
  if let data = lowercontent.data(using:.utf8) {
    let zz = try JSONDecoder().decode([Challenge].self,from:data)
    let elapsed = String(format:"%4.2f",Date().timeIntervalSince(started))
    print(">Repair response \(zz.count) blocks elapsed \(elapsed) ok\n")
    qmeBuf = lowercontent // stash as string
    //T9 - write each challenge separetly to the file systwm
    if grepairtemplate != "" {
      let (fpc,lpc,rpc) = getFileNameAndExtension(from: grepairtemplate)
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      var data:Data
      for z in zz {
//        if  z.hint != "" {
//          if !z.hint.hasSuffix(".") { // if no period then add one
//            print("NO PERIOD AT END OF HINT")
//            data = try encoder.encode(Challenge(question: z.question, topic: z.topic, hint: z.hint+".", answers: z.answers, correct: z.correct, id: z.id, date: z.date, aisource: z.aisource))
//          } else {
            data = try encoder.encode(z)
     //     }
          if let str1 = String(data:data,encoding: .utf8)  {
            let filespec = fpc+lpc+"_"+z.topic+"_"+z.id+"."+rpc
            
            // global stats
            totalRepaired += 1
            
            if  let repairedhandle = try prep9(filespec,initial:"") {
              repairedhandle.write(str1.data(using: .utf8)!)
              repairedhandle.closeFile()
              print("   \(z.question)")
            }
          }
        }
      }
    }
  }
fileprivate func decodePumpingArray(_ content: String,_ started:Date, _ usage:Usage?) throws {
  
  totalTokens += usage?.total_tokens ?? 0
  completionTokens += usage?.completion_tokens ?? 0
  promptTokens += usage?.prompt_tokens ?? 0
  if gverbose {print("\(content)")}
  let lowercontent  = rewriteJSON(content) ?? "FAIL"
  if let data = lowercontent.data(using:.utf8) {
    let zz = try JSONDecoder().decode([QuestionsModelEntry].self,from:data)
    let elapsed = String(format:"%4.2f",Date().timeIntervalSince(started))
    print(">Primary response \(zz.count) blocks elapsed \(elapsed) ok\n")
    // now convert the blocks into new format
    let zzz = zz.map {$0.makeChallenge()}
    let ppp = try JSONEncoder().encode(zzz)
    let str = String(data:ppp,encoding: .utf8) ?? ""
    qmeBuf = str // stash as string
    //T9 - write each challenge separetly to the file systwm
    if gpumptemplate != "" {
      let (fpc,lpc,rpc) = getFileNameAndExtension(from: skiprepair ? grepairtemplate : gpumptemplate)
  
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      for z in zzz {
        let data = try encoder.encode(z)
        if let str1 = String(data:data,encoding: .utf8)  {
          let filespec = fpc+lpc+"_"+z.topic+"_"+z.id+"."+rpc
          // global stats
          totalPumped += 1
          if  let pumpHandle = try prep9(filespec,initial:"") {
            pumpHandle.write(str1.data(using: .utf8)!)
            pumpHandle.closeFile()
            print("   \(z.question)")
          }
        }
      }
    }
  }
}



typealias DecoderFunc =  (String,Date,Usage?) throws -> Void

func callAI(msg1:String,msg2:String,
            decoder:@escaping DecoderFunc) async throws {
  try await callOpenAI(APIKey: apiKey,
                       decoder: decoder,
                       model: gmodel,
                       timeout:gtimeout,
                       maxtokens:gmaxtokens,
                       systemMessage:  msg1,
                       userMessage: msg2)
}

func rewriteJSON(_ input: String) -> String? {
  guard let jsonData = input.data(using: .utf8) else {
    return nil
  }
  
  guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
    return nil
  }
  
  let processedObject = lowercaseAndSortAny(jsonObject)
  
  guard let processedJsonData = try? JSONSerialization.data(withJSONObject: processedObject, options: [.sortedKeys, .prettyPrinted]) else {
    return nil
  }
  
  return String(data: processedJsonData, encoding: .utf8)
}

func lowercaseAndSortAny(_ value: Any) -> Any {
  if let dict = value as? [String: Any] {
    return lowercaseAndSortDict(dict)
  } else if let array = value as? [Any] {
    return array.map { lowercaseAndSortAny($0) }
  } else {
    return value
  }
}

private func lowercaseAndSortDict(_ dict: [String: Any]) -> [String: Any] {
  var lowercaseSortedDict = [String: Any]()
  
  let sortedKeys = dict.keys.map { $0.lowercased() }.sorted()
  for key in sortedKeys {
    if let originalValue = dict.first(where: { $0.key.lowercased() == key })?.value {
      lowercaseSortedDict[key] = lowercaseAndSortAny(originalValue)
    }
  }
  return lowercaseSortedDict
}


func test1() {
  // Example usage:
  let jsonString = """
[{
    "Name": "John Doe",
    "Age": 30,
    "Address": {
        "Street": "123 Elm St.",
        "City": "Springfield"
    }
}]
"""
  
  if let lowercasedJson = rewriteJSON( jsonString) {
    print(lowercasedJson)
  }
  else {
    print ("could not rewrite JSON \(jsonString)")
  }
  
  
}

