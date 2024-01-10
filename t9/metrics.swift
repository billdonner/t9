//
//  metrics.swift
//  t9
//
//  Created by bill donner on 1/9/24.
//

import Foundation
struct Usage: Codable {
  let completion_tokens:Int
  let prompt_tokens:Int
  let total_tokens:Int
}

// Define a structure that matches the response from chatgpt api
struct Response: Codable {
//    struct Model: Codable {
//        let model: String
//        let parametersCreated: String
//        enum CodingKeys: String, CodingKey {
//            case model
//            case parametersCreated = "params.created"
//        }
//    }

    struct Choices: Codable {
        struct Metrics: Codable {
            let accuracy: Float?
            let f1: Float?
            let precision: Float?
            let recall: Float?
            let roc_auc: Float?
        }

      //  let text: String
        let finish_reason: String
        let metrics: Metrics?
    }

    let id: String
    let model: String//Model
    let choices: [Choices]
    let usage : Usage?
}

func get_usage_metrics (_ jsonData:Data) -> Usage? {
  
  do {
    let response = try JSONDecoder().decode(Response.self, from: jsonData)

    for choice in response.choices {
      if let metrics = choice.metrics {
        print("Accuracy: \(String(describing: metrics.accuracy))")
        print("F1: \(String(describing: metrics.f1))")
        print("Precision: \(String(describing: metrics.precision))")
        print("Recall: \(String(describing: metrics.recall))")
        print("Roc Auc: \(String(describing: metrics.roc_auc))")
        
      }
    }
    
    if let usage = response.usage {
//      print("Completion Tokens: \(String(describing: usage.completion_tokens))")
//      print("Prompt Tokens: \(String(describing: usage.prompt_tokens))")
//      print("Total Tokens: \(String(describing: usage.total_tokens))")
      return usage
    }
    
  } catch {
    print("error: \(error)")
  }
  return nil
}

struct ModelCosts {
  internal init(_ cptIn: Double,_ cptOut: Double) {
    self.cptIn = cptIn
    self.cptOut = cptOut
  }
  
  let cptIn:Double // cost per thousand
  let cptOut:Double
}

func computeTotalCost(completionTokenCount: Int, promptTokenCount: Int, model: String) -> Double {
  
let modelsDict:[String:ModelCosts] = [
  "gpt-3.5-turbo-1106":ModelCosts(0.0010,0.0020),// max output tokens is 16385
  "gpt-4-1106-preview":ModelCosts(0.01,0.03),//json mode, max output tokens is 4096
  "gpt-4":ModelCosts(0.03,0.06),//max tokens is 8192
  "gpt-32k":ModelCosts(0.06,0.12),//max tokens is 32768
]
let unknownModel = ModelCosts(0.05,0.05)

    // Set the base cost per token depending on the model
   let cost = modelsDict[model] ?? unknownModel
  
    // Calculate the total cost in USD
  let totalCost = cost.cptIn * Double(promptTokenCount)/1000.0 + cost.cptOut * Double(completionTokenCount)/1000.0
    
    return totalCost
}
