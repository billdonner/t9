//
//  parsing.swift
//  t7
//
//  Created by bill donner on 12/9/23.
//

import Foundation
import q20kshare
import ArgumentParser



func prep9(_ x:String, initial:String) throws  -> FileHandle? {
 if (FileManager.default.createFile(atPath: x, contents: nil, attributes: nil)) {
//   print(">Created \(x)")
 } else {
   print("\(x) not created."); throw PumpingErrors.badOutputURL
 }
 guard let  newurl = URL(string:x)  else {
   print("\(x) is a bad url"); throw PumpingErrors.badOutputURL
 }
 do {
   let  fh = try FileHandle(forWritingTo: newurl)
   fh.write(initial.data(using: .utf8)!)
   return fh
 } catch {
   print("Cant write to \(newurl), \(error)")
   throw PumpingErrors.cantWrite
 }
}
struct T9: ParsableCommand   {
  
  static var configuration = CommandConfiguration(
    abstract: "Chat With AI To Generate Data for Q20K (IOS) App",
    discussion: "Step 1 - ask the AI to generate question blocks a\nStep 2 - ask the AI to repair the data\n\n\n The pumpedtemplate and repairedtemple are full file paths which generate an output file path that  will be modified as each file is processed",
    version: t9_version )
  
  @Argument(help: "pumper system template URL")
  var pumpsys: String
  
  @Argument( help:"pumper user template URL")
  var pumpusr: String
  
  @Option(help: "validation system template URL, default is no validation")
  var valsys: String = ""
  
  @Option( help:"validation user template URL, default is \"\"")
  var valusr: String = ""
  
  @Option(help: "repair system template URL, default is no repair")
  var repsys: String = ""
  
  @Option( help:"repair user template URL, default is \"\"")
  var repusr: String = ""
  
  @Option(help: "re-validation system template URL, default is no revalidation")
  var revalsys: String = ""
  
  @Option( help:"re-validation user template URL, default is \"\"")
  var revalusr: String = ""
  
  @Option( help:"alternate pumper input URL, default is \"\"")
  var altpump: String = ""
  
  @Option( help:"pumpedoutput template for output  json files")
  var pumpedtemplate: String = ""
  
  @Option( help:"repaired template for output json files")
  var repairedtemplate: String = ""
  
//  @Option( help:"validated json stream file")
//  var validatedfile: String = ""
//  
//  @Option( help:"revalidated json stream file")
//  var revalidatedfile: String = ""
  
  @Option( help:"model")
  var model: String = "gpt-4"
  
  @Flag (help:"verbose")
  var verbose : Bool = false 
  
  @Flag (help:"keep looping thru pumpusr")
  var looper = false
  
  @Option(help:"AI timeout in seconds")
  var timeout = 120
  @Option(help:"AI Max TOKENS")
  var maxtokens = 4000

  mutating func process_cli() throws {
    // move some of these struct local things for argument parser into global variables!!
    glooper = looper 
    gtimeout = Double(timeout)
    gmaxtokens = maxtokens
    gpumptemplate = pumpedtemplate
    grepairtemplate = repairedtemplate
    gverbose = verbose
    gmodel = model
    // get required template data, no defaults
    guard let sys = URL(string:pumpsys) else {
      throw T9Errors.badInputURL(url: pumpsys)
    }
    guard let usr = URL(string:pumpusr) else {
      throw T9Errors.badInputURL(url: pumpusr)
    }
    let sysMessage = try String(data:Data(contentsOf:sys),encoding: .utf8)
    guard let sysMessage = sysMessage else {throw T9Errors.cantDecode(url: pumpsys)}
    systemMessage = sysMessage
    
    let userMessage = try String(data:Data(contentsOf:usr),encoding: .utf8)
    guard let userMessage = userMessage else {throw T9Errors.cantDecode(url: pumpusr)}
    usrMessage = userMessage
        // validation
    if valusr == "" {
      valusrMessage = ""
    } else {
      guard let valusr = URL(string:valusr) else {
        throw T9Errors.badInputURL(url: valusr)
      }
      valusrMessage = try String(data:Data(contentsOf:valusr),encoding: .utf8) ?? ""
    } 
    if valsys == "" {
      valsysMessage = ""
    } else {
      guard let valsys = URL(string:valsys) else {
        throw T9Errors.badInputURL(url: valsys)
      }
      valsysMessage = try String(data:Data(contentsOf:valsys),encoding: .utf8) ?? ""
      skipvalidation = false
    }
    
    // repair
    if repusr == "" {
      repusrMessage = ""
    } else {
      guard let repusr = URL(string:repusr) else {
        throw T9Errors.badInputURL(url: repusr)
      }
      repusrMessage = try String(data:Data(contentsOf:repusr),encoding: .utf8) ?? ""
    }
    if repsys == "" {
      repsysMessage = ""
      skiprepair = true
    } else {
      guard let repsys = URL(string:repsys) else {
          throw T9Errors.badInputURL(url: repsys)
      }
      repsysMessage = try String(data:Data(contentsOf:repsys),encoding: .utf8) ?? ""
    }
    
    // validation
    
    if revalusr == "" {
      revalusrMessage = ""
    } else {
      guard let revalusr = URL(string:revalusr) else {
        throw T9Errors.badInputURL(url: revalusr)
      }
      revalusrMessage = try String(data:Data(contentsOf:revalusr),encoding: .utf8) ?? ""
    }
    
    if revalsys == "" {
      revalsysMessage = "" 
    } else {
      guard let revalsys = URL(string:revalsys) else {
        throw T9Errors.badInputURL(url: revalsys)
      }
      revalsysMessage = try String(data:Data(contentsOf:revalsys),encoding: .utf8) ?? ""
      skiprevalidation = false
    }

//    if validatedfile != "" {
//    validatedHandle = try?  prep9(validatedfile,initial:"")// "[\n")
//    }
//
//    if revalidatedfile != "" {
//     revalidatedHandle = try?  prep9(revalidatedfile,initial:"")// "[\n")
//    }
  }

  
  mutating func run()   throws {
    do {
      try process_cli()
    }
    catch {
      print("Error -> \(error)")
      throw T9Errors.commandLineError
    }
    showTemplates()
    apiKey = try getAPIKey() 
  }
}
 
