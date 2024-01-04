//
//  phases.swift
//  t7
//
//  Created by bill donner on 12/9/23.
//

import Foundation
import q20kshare


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
func repairPhase(_ userMessage:String) async throws{
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
      print("\n=========== Job \(jobno) \(gmodel) ============")
      if performPhases[0] {
        try await pumpPhase(msg)}
      else {print ("Skipping pumpPhase")}
      if performPhases[1] {
        try await validationPhase()}
      else {print ("Skipping validationPhase")}
      if performPhases[2] {
        try await repairPhase(msg)}
      else {print ("Skipping repairPhase")}
      if performPhases[3] {
        try await revalidationPhase()}
      else {print ("Skipping revalidationPhase")}
    }
    catch {
      print("\n=========== Cancelling Job \(jobno) ============")
      print(error)
    }
  }
}
  
  // Function to call the OpenAI API
  
  fileprivate func decodeValidationResponse(_ content: String,_ started:Date, _ needscomma:Bool) throws {
    let elapsed = String(format:"%4.2f",Date().timeIntervalSince(started))
    print(">AI validation response \(content.count) bytes in \(elapsed) secs \n\(content)")
    if let validatedHandle = validatedHandle {
      validatedHandle.write(content.data(using:.utf8)!)
    }
  }
  fileprivate func decodeReValidationResponse(_ content: String,_ started:Date, _ needscomma:Bool) throws {
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
  fileprivate func decodeQuestionsArray(_ content: String,_ started:Date, _ needscomma:Bool) throws {
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
        for z in zz {
          let data = try encoder.encode(z)
          if let str1 = String(data:data,encoding: .utf8)  {
            //let str2 = lowercasedJSONFieldNames(jsonString: str1) ?? "FAIL"
            let filespec = fpc+lpc+"_"+z.topic+"_"+z.id+"."+rpc
            if  let repairedhandle = try prep9(filespec,initial:"") {
              repairedhandle.write(str1.data(using: .utf8)!)
              repairedhandle.closeFile()
              totalRepaired += 1
              print("   \(z.question)")
            }
          }
        }
      }
    }
  }
  
  fileprivate func decodePumpingArray(_ content: String,_ started:Date, _ needscomma:Bool) throws {
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
        let (fpc,lpc,rpc) = getFileNameAndExtension(from: gpumptemplate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        for z in zzz {
          let data = try encoder.encode(z)
          if let str1 = String(data:data,encoding: .utf8)  {
            //let str2 = lowercasedJSONFieldNames(jsonString: str1) ?? "FAIL"
            let filespec = fpc+lpc+"_"+z.topic+"_"+z.id+"."+rpc
            if  let pumpHandle = try prep9(filespec,initial:"") {
              pumpHandle.write(str1.data(using: .utf8)!)
              pumpHandle.closeFile()
              totalPumped += 1
              print("   \(z.question)")
            }
          }
        }
      }
    }
  }
  
  
  
  typealias DecoderFunc =  (String,Date,Bool) throws -> Void
  
  func callAI(msg1:String,msg2:String,
              decoder:@escaping DecoderFunc) async throws {
    try await callOpenAI(APIKey: apiKey,
                         decoder: decoder,
                         model: gmodel,
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


////////
///
///
 /**
func lowercasedJSONFieldNames(jsonString: String) -> String? {
    guard let jsonData = jsonString.data(using: .utf8),
          var jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
        return nil
    }
    
    jsonDict = lowercasedKeys(dictionary: jsonDict)

    let sortedDict = jsonDict.sorted(by: { $0.key < $1.key }).reduce(into: [String: Any]()) {
        $0[$1.key] = $1.value
    }

  guard let processedJsonData = try? JSONSerialization.data(withJSONObject: sortedDict, options: [.prettyPrinted]),
          let processedJsonString = String(data: processedJsonData, encoding: .utf8) else {
        return nil
    }
    
    return processedJsonString
}

func lowercasedKeys(dictionary: [String: Any]) -> [String: Any] {
    var newDict = [String: Any]()

    for (key, value) in dictionary.sorted(by: { $0.key < $1.key }) {
        let lowerKey = key.lowercased()
        
        if let subDict = value as? [String: Any] {
            newDict[lowerKey] = lowercasedKeys(dictionary: subDict)
        } else if let array = value as? [Any] {
            newDict[lowerKey] = lowercasedArray(array: array)
        } else {
            newDict[lowerKey] = value
        }
    }

    return newDict
}

func lowercasedArray(array: [Any]) -> [Any] {
    return array.map { item in
        if let itemDict = item as? [String: Any] {
            return lowercasedKeys(dictionary: itemDict)
        } else {
            return item
        }
    }
}

  func lowercasedJSONFieldNames(jsonString: String) -> String? {
    // Parse the JSON string into a dictionary
    guard let jsonData = jsonString.data(using: .utf8),
          var jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
      return nil
    }
    
    // Process the dictionary to lowercase all keys
    jsonDict = lowercasedKeys(dictionary: jsonDict)
    
    // Serialize the processed dictionary back into a JSON string
    guard let processedJsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted]),
          let processedJsonString = String(data: processedJsonData, encoding: .utf8) else {
      return nil
    }
    
    return processedJsonString
  }
  fileprivate func lowercasedKeys(dictionary: [String: Any]) -> [String: Any] {
    var newDict = [String: Any]()
    
    for (key, value) in dictionary {
      // Lowercase the key
      let lowerKey = key.lowercased()
      
      ///
      /// see if actually changing
      
      if key != lowerKey {
        print("***Bad UC JSON field \(key)")
      }
      
      // Check if the value is a dictionary or an array and recursively process them
      if let subDict = value as? [String: Any] {
        newDict[lowerKey] = lowercasedKeys(dictionary: subDict)
      } else if let array = value as? [Any] {
        newDict[lowerKey] = lowercasedArray(array: array)
      } else {
        newDict[lowerKey] = value
      }
    }
    
    return newDict
  }
  
 fileprivate func lowercasedArray(array: [Any]) -> [Any] {
    return array.map { item in
      if let itemDict = item as? [String: Any] {
        return lowercasedKeys(dictionary: itemDict)
      } else {
        return item
      }
    }
  }
*/
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

