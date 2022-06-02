/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreBluetooth
let kinsaTempUUID:UUID = UUID(uuidString:"00000000-006B-746C-6165-4861736E694B")!
let kinsaTempCBUUID:CBUUID = CBUUID(nsuuid: kinsaTempUUID)
let tempServiceCBUUID = CBUUID(nsuuid: kinsaTempUUID )
//
class HRMViewController: UIViewController {

  @IBOutlet weak var heartRateLabel: UILabel!
  @IBOutlet weak var bodySensorLocationLabel: UILabel!
  
  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral!
  var kinsaService: CBService!



  override func viewDidLoad() {
    super.viewDidLoad()
    centralManager = CBCentralManager(delegate: self, queue: nil)
    


    // Make the digits monospaces to avoid shifting when the numbers change
    heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
  }

  func onHeartRateReceived(_ heartRate: Double) {
    heartRateLabel.text = String(heartRate)
    print("BPM: \(heartRate)")
  }
}
extension HRMViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
      switch central.state {
        case .unknown:
          print("central.state is .unknown")
        case .resetting:
          print("central.state is .resetting")
        case .unsupported:
          print("central.state is .unsupported")
        case .unauthorized:
          print("central.state is .unauthorized")
        case .poweredOff:
          print("central.state is .poweredOff")
        case .poweredOn:
          print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: nil)
         // centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])

        @unknown default:
         print("unknown default")
      }
    
  }
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    //print(peripheral)
    if peripheral.name == "Kinsa"{
    print(peripheral)
      heartRatePeripheral = peripheral
      heartRatePeripheral.delegate = self
      centralManager.stopScan()
      centralManager.connect(heartRatePeripheral)
      
    }
  }
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    heartRatePeripheral.discoverServices(nil)

  }




}

extension HRMViewController: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }

    for service in services {
      if service.uuid.uuidString == "00000000-006B-746C-6165-4861736E694B" {
        kinsaService = service
        print(kinsaService!)
        peripheral.discoverCharacteristics(nil, for: kinsaService)

      }
      
    }
    
  }
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                  error: Error?) {
    guard let characteristics = service.characteristics else { return }

    for characteristic in characteristics {
      print(characteristic)
      heartRatePeripheral.discoverDescriptors(for: characteristic)
      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
      }
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        heartRatePeripheral.setNotifyValue(true, for: characteristic)
        
      }
    }
  }
  // In CBPeripheralDelegate class/extension
  func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
      guard let descriptors = characteristic.descriptors else { return }
   
      // Get user description descriptor
      if let userDescriptionDescriptor = descriptors.first(where: {
          return $0.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString
      }) {
          // Read user description for characteristic
          peripheral.readValue(for: userDescriptionDescriptor)
      }
  }
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
   
    
       // print("Unhandled Characteristic UUID: \(characteristic)")
        let temp = finalTemp(from: characteristic)
        onHeartRateReceived(temp)
    
        print("Unhandled Characteristic UUID: \(characteristic)")
    
  }
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
      // Get and print user description for a given characteristic
      if descriptor.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString,
          let userDescription = descriptor.value as? String {
          print("Characterstic \(descriptor.characteristic.uuid.uuidString) is also known as \(userDescription)")
      }
  }
  private func heartRate(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)
    
    let firstBitValue = byteArray[0] & 0x01
    if firstBitValue == 0 {
      // Heart Rate Value Format is in the 2nd byte
      return Int(byteArray[1])
    } else {
      // Heart Rate Value Format is in the 2nd and 3rd bytes
      return (Int(byteArray[1]) << 8) + Int(byteArray[2])
    }
  }
  fileprivate enum MessageHeader: UInt8 {
      case dateTime           = 0x06
      case error              = 0x07
      case mac                = 0x08
      case ready              = 0x0A
      case disconnected       = 0x0D
      case ascii              = 0x30
      case readingUpdate      = 0x42
      case readingComplete    = 0x46
  }
  private func finalTemp(from characteristic: CBCharacteristic) -> Double {
    var temp: Double = 0.0
    guard let data = characteristic.value else { return 0.0 }


    let firstByte = data.subdata(in: 0...1)
    let header = UInt8(littleEndian: firstByte.withUnsafeBytes { $0.load(as: UInt8.self) })
    if  let messageHeader = MessageHeader(rawValue: header) {
      print("header \(messageHeader)")
    
    switch messageHeader {
      case .dateTime:
        let bytes = self.readBytes(data: data, range: 1...6)
        if let date = self.parseDateTime(bytes: bytes) {
           print("Date/Time receieved from thermometer:\(date.description)" )
        } else {
          print("Unable to parse data \(data.description)")
        }
      case .error:
        print("Error" )
      case .mac:
        print("Mac" )
      case .ready:
        print("REady" )
      case .disconnected:
        print("Disconnected" )
      case .ascii:
        let bytes = self.readBytes(data: data, range: 1...16)
        if let text = self.parseText(bytes: bytes) {
            print("Text receieved from thermometer: \(text)")
        } else {
            print("Unable to parse data: \(data.description)")
        }
        print("Error" )
      case .readingUpdate:
       print("reading")
        if let measurement = self.readTemperature(from: data) {
          temp = measurement.value
          print( "Temp receieved from thermometer: \(measurement)")
        } else {
          print("Unable to parse data: \(data.description)")
        }
      case .readingComplete:
        if let measurement = self.readTemperature(from: data) {
          temp = measurement.value
          print( "Temp receieved from thermometer: \(measurement)")
        } else {
          print("Unable to parse data: \(data.description)")
        }
    }
    } else {
        print("Unrecognized header \(header)")
      
    }
   
   return temp
  }
  fileprivate func parseDateTime(bytes: [UInt8]) -> Date? {
      guard bytes.count == 6 else {
          return nil
      }
      
      let cal = Calendar(identifier: .gregorian)
      var comps = DateComponents()
      comps.year = Int(bytes[0])
      comps.month = Int(bytes[1])
      comps.day = Int(bytes[2])
      comps.hour = Int(bytes[3])
      comps.minute = Int(bytes[4])
      comps.second = Int(bytes[5])

      let date = cal.date(from: comps)
      
      return date
  }
  
  fileprivate func readBytes(data: Data, range: ClosedRange<Int>) -> [UInt8] {
      let subBytes = data.subdata(in: range)
      var bytes = [UInt8]()
      bytes.append(contentsOf: subBytes)
      
      return bytes
  }
  fileprivate func parseText(bytes: [UInt8]) -> String? {
      guard bytes.count > 0 else {
          return nil
      }
      
      var message = ""
      
      for byte in bytes {
          guard byte != 0 else {
              return message
          }
          
          message.append(Character(UnicodeScalar(byte)))
      }
      
      return message
  }
  fileprivate func readTemperature(from data: Data) -> Measurement<UnitTemperature>? {
      guard data.count >= 4 else {
          print("Expected data >= 4")
          return nil
      }
      
      var bytes = self.readBytes(data: data, range: 2...3)
      bytes.insert(0, at: 0)
      bytes.insert(0, at: 0)

      var rawTemperature : UInt32 = 0
      let data = NSData(bytes: bytes, length: bytes.count)
      data.getBytes(&rawTemperature, length: bytes.count)
      rawTemperature = UInt32(bigEndian: rawTemperature)
      
      let temperature = Double(rawTemperature) / 10.0
      let measurement = Measurement<UnitTemperature>(value: temperature, unit: .celsius)
      
      print("Raw temperature:\(rawTemperature)")
      print("Measurement: \(measurement.value)")
      
      return measurement
  }
  
}
extension Data {
    func subdata(in range: ClosedRange<Index>) -> Data {
        return subdata(in: range.lowerBound ..< range.upperBound + 1)
    }
}
