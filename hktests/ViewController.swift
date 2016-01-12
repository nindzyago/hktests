//
//  ViewController.swift
//  hktests
//
//  Created by apple on 27.12.15.
//  Copyright © 2015 techmas.ru. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {

    let healthKitStore: HKHealthStore = HKHealthStore()

    
    func authorizeHealthKit(completion: ((success:Bool, error:NSError!) -> Void)!) {
        let healthKitTypesToRead = Set(arrayLiteral:
            HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!,
            HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex)!
        )
        let healthKitTypesToWrite = Set(arrayLiteral:
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMassIndex)!,
            HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!
        )
        
        if !HKHealthStore.isHealthDataAvailable()
        {
            let error = NSError(domain: "ru.techmas.techmasHealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey:"HealthKit is not available in this Device"])
            if( completion != nil )
            {
                completion(success:false, error:error)
            }
            return;
        }
        healthKitStore.requestAuthorizationToShareTypes(healthKitTypesToWrite, readTypes: healthKitTypesToRead) {
            (success, error) -> Void in
            if( completion != nil )
            {
                completion(success:success,error:error)
            }
        }
    }
    
    func readProfile() -> (age:NSDate?, bioSex:HKBiologicalSexObject?)
    {
        // Reading Characteristics
        var bioSex : HKBiologicalSexObject?
        var dateOfBirth : NSDate?
        
        do {
            dateOfBirth = try healthKitStore.dateOfBirth()
            bioSex = try healthKitStore.biologicalSex()
        }
        catch {
            print(error)
        }
        return (dateOfBirth, bioSex)
    }
    
    func readMostRecentSample(sampleType:HKSampleType , completion: ((HKSample!, NSError!) -> Void)!)
    {
        
        // 1. Build the Predicate
        let past = NSDate.distantPast()
        let now   = NSDate()
        let mostRecentPredicate = HKQuery.predicateForSamplesWithStartDate(past, endDate:now, options: .None)
        
        // 2. Build the sort descriptor to return the samples in descending order
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        // 3. we want to limit the number of samples returned by the query to just 1 (the most recent)
        let limit = 1
        
        // 4. Build samples query
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: mostRecentPredicate, limit: limit, sortDescriptors: [sortDescriptor])
            { (sampleQuery, results, error ) -> Void in
                
                if let queryError = error {
                    completion(nil,error)
                    return;
                }
                
                // Get the first sample
                let mostRecentSample = results!.first as? HKQuantitySample
                
                // Execute the completion closure
                if completion != nil {
                    completion(mostRecentSample,nil)
                }
        }
        // 5. Execute the Query
        self.healthKitStore.executeQuery(sampleQuery)
    }

    func saveBMISample(bmi:Double, date:NSDate ) {
        
        // 1. Create a BMI Sample
        let bmiType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMassIndex)
        let bmiQuantity = HKQuantity(unit: HKUnit.countUnit(), doubleValue: bmi)
        let bmiSample = HKQuantitySample(type: bmiType!, quantity: bmiQuantity, startDate: date, endDate: date)
        
        // 2. Save the sample in the store
        healthKitStore.saveObject(bmiSample, withCompletion: { (success, error) -> Void in
            if( error != nil ) {
                print("Error saving BMI sample: \(error!.localizedDescription)")
            } else {
                print("BMI sample saved successfully!")
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        authorizeHealthKit { (authorized,  error) -> Void in
            if authorized {
                print("HealthKit authorization received.")
                let profile = self.readProfile()
                print(profile)
                
                var kilograms: Double = 0.0

                // 1. Construct an HKSampleType for weight
                let sampleType = HKSampleType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)
                
                // 2. Call the method to read the most recent weight sample
                self.readMostRecentSample(sampleType!, completion: { (mostRecentWeight, error) -> Void in
                    
                    if( error != nil )
                    {
                        print("Error reading weight from HealthKit Store: \(error.localizedDescription)")
                        return;
                    }
                    var weight: HKQuantitySample
                    var weightLocalizedString = "empty"
                    // 3. Format the weight to display it on the screen
                    weight = (mostRecentWeight as? HKQuantitySample)!;
                    kilograms = weight.quantity.doubleValueForUnit(HKUnit.gramUnitWithMetricPrefix(.Kilo))
                    let weightFormatter = NSMassFormatter()
                    weightFormatter.forPersonMassUse = true;
                    weightLocalizedString = weightFormatter.stringFromKilograms(kilograms)
                    
                    // 4. Print the result
                    print(weightLocalizedString)

                    let weightInKilograms = kilograms
                    let heightInMeters: Double = 180
                    
                    let bmi  = weightInKilograms / heightInMeters * heightInMeters
                    
                    // 3. Show the calculated BMI
                    print(String(format: "%.02f", bmi))
                    
                    // Store bmi
                    self.saveBMISample(bmi, date: NSDate())

                    });

            }
            else
            {
                print("HealthKit authorization denied!")
                if error != nil {
                    print("\(error)")
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

