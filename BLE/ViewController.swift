//
//  ViewController.swift
//  BLE
//
//  Created by Ryota on 1/11/20.
//


import UIKit
import CoreBluetooth

let svcThermometer        = CBUUID.init(string: "00000001-710E-4A5B-8D75-3E5B444BC3CF")
let charThermometerConfig = CBUUID.init(string: "00000003-710E-4A5B-8D75-3E5B444BC3CF")
let charThermometerData   = CBUUID.init(string: "00000002-710E-4A5B-8D75-3E5B444BC3CF")

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @IBOutlet weak var tempLabel: UILabel!
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            if let pUUIDString = UserDefaults.standard.object(forKey: "PUUID") as? String{
                if let pUUID = UUID.init(uuidString: pUUIDString) {
                    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [pUUID])
                    if let p = peripherals.first {
                        connect(toPeripheral: p)
                        return
                    }
                }
            }
            
            let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [CBUUID.init(string: "AA80")])
            if let p = peripherals.first {
                connect(toPeripheral: p)
                return
            }
            
            central.scanForPeripherals(withServices: nil, options: nil)
            print ("scanning...")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("raspberrypi") == true {
            print (advertisementData)
            connect(toPeripheral: peripheral)
        }
    }
    
    func connect(toPeripheral : CBPeripheral) {
        print (toPeripheral.name ?? "no name")
        centralManager.stopScan()
        centralManager.connect(toPeripheral, options: nil)
        myPeripheral = toPeripheral
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print ("connected \(peripheral.name ?? "peripheral")")
        peripheral.discoverServices(nil)
        peripheral.delegate = self
        UserDefaults.standard.setValue(peripheral.identifier.uuidString, forKey: "PUUID")
        UserDefaults.standard.synchronize()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for svc in services {
                if svc.uuid == svcThermometer {
                    print (svc.uuid.uuidString)
                    peripheral.discoverCharacteristics(nil, for: svc)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let chars = service.characteristics {
            for char in chars {
                print (char.uuid.uuidString)
                if char.uuid == charThermometerConfig {
                    let charToSend: Character = "C"
                    let byteToSend: UInt8 = Array(String(charToSend).utf8)[0]
                    if char.properties.contains(CBCharacteristicProperties.writeWithoutResponse) {
                        peripheral.writeValue(Data([byteToSend]), for: char, type: CBCharacteristicWriteType.withoutResponse)
                    }
                    else {
                        peripheral.writeValue(Data([byteToSend]), for: char, type: CBCharacteristicWriteType.withResponse)
                    }
                }
                else if char.uuid == charThermometerData {
                    checkTemperature(curChar: char)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print ("wrote value")
    }
    
    func checkTemperature(curChar: CBCharacteristic) {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { (timer) in
            self.myPeripheral?.readValue(for: curChar)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let val = characteristic.value {
//            print (val)
//            print ("\([UInt8](val))")
            if let string = String(bytes: val, encoding: .utf8) {
                print(string)
                tempLabel.text = String(string)
            } else {
                print("not a valid UTF-8 sequence")
            }
        }
    }
    
    var centralManager : CBCentralManager!
    var myPeripheral : CBPeripheral?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager.init(delegate: self, queue: nil)
    }


}

