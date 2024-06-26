//
//  main.swift
//  t9
//
//  Created by bill donner on 12/9/23.
//

import Foundation
import q20kshare
import ArgumentParser

let t9_version = "0.5.10"

public enum T9Errors: Error {
  case commandLineError
  case badResponseFromAI
  case badInputURL(url:String)
  case badOutputURL(url:String)
  case cantDecode(url:String)
  case cantWrite
  case noAPIKey
  case onlyLocalFilesSupported
  case reachedMaxLimit
  case reachedEndOfScript
}

struct QuestionsModelEntry: Codable {
  let question:String
  let answers:[String]
  let correct:String
  let explanation:String
  let hint:String
  let topic:String
  
  func makeChallenge( )  -> Challenge {
    let from = self
    return Challenge(question: from.question,
                     topic: from.topic,
                     hint: from.hint,
                     answers: from.answers,
                     correct: from.correct,
                     explanation: from.explanation,
                     id:UUID().uuidString, 
                     date: uniqueDate() ,
                     aisource:gmodel)
  }
}
func uniqueDate() -> Date { 
  var x = Date()
  if lastDate != nil , lastDate == x {
    x += 9 // make these unique even if called repeatedly
  }
  lastDate = x
  return x
}
var lastDate:Date? = nil
var qmeBuf:String = ""

var firsttime = true
var valusrMessage : String = ""
var valsysMessage : String = ""
var revalusrMessage : String = ""
var revalsysMessage : String = ""
var repusrMessage : String = ""
var repsysMessage : String = ""
var systemMessage : String = ""
var usrMessage : String = ""

var gmodel:String = ""
var gverbose: Bool = false
var gpumptemplate:String = ""
var grepairtemplate:String = ""
var apiKey:String = ""

var skipvalidation: Bool = true
var skiprepair: Bool = false
var skiprevalidation: Bool = true

var validatedHandle: FileHandle?
var revalidatedHandle: FileHandle?

var firstrepaired = false
var firstpumped = false

var phasescount = 4

var totalPumped = 0
var totalRepaired = 0
var totalTokens = 0
var promptTokens = 0
var completionTokens = 0
var totalJobs = 0
var succesfullJobs = 0

var glooper = false
var gtimeout:TimeInterval = 0
var gmaxtokens = 0

func showTemplates() {
  print("+========T E M P L A T E S =========+")
  print("<<<<<<<<systemMessage>>>>>>>>>>",systemMessage)
  print("<<<<<<<<usrMessage>>>>>>>>>>","--displayed per api cycle--")
  print("<<<<<<<<valusrMessage>>>>>>>>>>",valusrMessage)
  print("<<<<<<<<valsysMessage>>>>>>>>>>",valsysMessage)
  print("<<<<<<<<repusrMessage>>>>>>>>>>",repusrMessage)
  print("<<<<<<<<repsysMessage>>>>>>>>>>",repsysMessage)
  print("+====== E N D  T E M P L A T E S =====+")
}

func runAICycle (_ userMessage:String,jobno:String) async throws{
  var phases:[Bool] = [true]// [altpump.isEmpty]
  phases += [!skipvalidation]
  phases += [!skiprepair]
  phases += [!skiprevalidation]
  try await Phases.perform(phases, jobno: jobno,msg:userMessage)
}


func bigLoop () {
  let tmsgs = usrMessage.components(separatedBy: "*****")
  let umsgs = tmsgs.compactMap{$0.trimmingCharacters(in: .whitespacesAndNewlines)}
  phasescount = umsgs.count
  Task  {
    for str in umsgs {
      do {
        try await   runAICycle(str, jobno: UUID().uuidString)
        phasescount -= 1
        firsttime = false
      }
      catch {
        print("AI returns with \(error)")
        phasescount = 0
        break
      }
    }
  }
}
 //jsonSortTest()

let startTime = Date()
print(">T9 Command Line: \(CommandLine.arguments)")
repeat {
  T9.main()
  // big Loop runs async calls
  bigLoop()
  // wait for all phases to finish
  var j = 0
  var even = true
  while phasescount > 0  {
    sleep(1)
    j += 1
    if j % 10 == 0  {
      print(even ? "|" : "-",terminator:"")
      even = !even
    }
  }
  if let validatedHandle = validatedHandle { validatedHandle.closeFile()}
  if let revalidatedHandle = revalidatedHandle { revalidatedHandle.closeFile()}
} while glooper


showStats("FINAL")
//print("\nExiting, pumped \(totalPumped) and repaired \(totalRepaired) using \(gmodel); ct=\(completionTokens) pt=\(promptTokens) cost=\(d);\n
print("All work completed to the best of our abilities")

func sortJSON(json: Any) -> Any {
    if var dict = json as? [String: Any] {
        var sortedDict = [String: Any]()
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            sortedDict[key] = sortJSON(json: value)
        }
        return sortedDict
    } else if var array = json as? [Any] {
        for (index, value) in array.enumerated() {
            array[index] = sortJSON(json: value)
        }
        return array
    } else {
        return json
    }
}

func jsonSortTest() {
  // Sample usage
  let json: [String: Any] = [
    "b": "value",
    "a": 123,
    "c": [
      "z": "nestedValue",
      "x": 456,
      "y": ["hello", "world"]
    ]
  ]
  
  if let sortedJSON = sortJSON(json: json) as? [String: Any] {
    if let jsonData = try? JSONSerialization.data(withJSONObject: sortedJSON, options: [.prettyPrinted]),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      print(jsonString)
    }
  }
}
