import Foundation
import CoreLocation
import Combine

// MARK: - 位置服务
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var currentCity: String = "定位中..."
    @Published var currentDistrict: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating = false
    @Published var locationError: String?
    
    // 完整地址
    var fullAddress: String {
        if currentDistrict.isEmpty {
            return currentCity
        }
        return "\(currentCity)\(currentDistrict)"
    }
    
    // 简短地址（用于显示）
    var shortAddress: String {
        if !currentDistrict.isEmpty {
            return currentDistrict
        }
        if currentCity != "定位中..." && currentCity != "定位失败" {
            return currentCity
        }
        return "附近"
    }
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // 请求定位权限
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // 开始定位
    func startLocating() {
        isLocating = true
        locationError = nil
        
        print("📍 开始定位，当前权限状态: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .notDetermined:
            print("📍 权限未确定，请求权限...")
            requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 已授权，开始获取位置...")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("📍 权限被拒绝或受限")
            isLocating = false
            currentCity = "定位失败"
            locationError = "请在设置中开启定位权限"
        @unknown default:
            print("📍 未知权限状态")
            isLocating = false
            currentCity = "定位失败"
        }
    }
    
    // 停止定位
    func stopLocating() {
        locationManager.stopUpdatingLocation()
        isLocating = false
    }
    
    // 刷新定位
    func refreshLocation() {
        currentCity = "定位中..."
        currentDistrict = ""
        startLocating()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { 
            print("📍 没有获取到位置")
            return 
        }
        
        print("📍 获取到位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        currentLocation = location
        stopLocating()
        
        // 反向地理编码获取地址
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLocating = false
                
                if let error = error {
                    let nsError = error as NSError
                    
                    // 根据错误类型提供更友好的提示
                    switch nsError.code {
                    case 8: // kCLErrorGeocodeFoundNoResult - 模拟器常见错误
                        // 静默处理，不打印日志
                        self?.currentCity = "当前位置"
                        self?.locationError = nil // 不显示错误，因为有坐标就够了
                    case 10: // kCLErrorGeocodeCanceled
                        #if DEBUG
                        print("📍 地理编码被取消")
                        #endif
                        self?.currentCity = "定位取消"
                    default:
                        #if DEBUG
                        print("📍 地理编码错误: \(error.localizedDescription) (Code: \(nsError.code))")
                        #endif
                        self?.currentCity = "当前位置"
                        self?.locationError = nil // 不显示错误给用户
                    }
                    return
                }
                
                if let placemark = placemarks?.first {
                    print("📍 地理编码结果: \(placemark)")
                    // 获取城市
                    if let city = placemark.locality {
                        self?.currentCity = city
                    } else if let administrativeArea = placemark.administrativeArea {
                        self?.currentCity = administrativeArea
                    } else {
                        self?.currentCity = "未知城市"
                    }
                    
                    // 获取区县
                    if let district = placemark.subLocality {
                        self?.currentDistrict = district
                    } else if let subAdministrativeArea = placemark.subAdministrativeArea {
                        self?.currentDistrict = subAdministrativeArea
                    }
                    
                    print("📍 定位成功: \(self?.currentCity ?? "") \(self?.currentDistrict ?? "")")
                } else {
                    // 没有错误但也没有结果
                    print("📍 未获取到地理信息")
                    self?.currentCity = "位置未知"
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 定位失败: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isLocating = false
            self?.currentCity = "定位失败"
            self?.locationError = error.localizedDescription
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 权限状态变更: \(manager.authorizationStatus.rawValue)")
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("📍 权限已授予，开始定位")
                self?.startLocating()
            case .denied, .restricted:
                print("📍 权限被拒绝")
                self?.currentCity = "定位失败"
                self?.locationError = "请在设置中开启定位权限"
            default:
                break
            }
        }
    }
    
    // 计算两点之间的距离（公里）
    func distanceTo(latitude: Double, longitude: Double) -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: latitude, longitude: longitude)
        return currentLocation.distance(from: targetLocation) / 1000.0
    }
}
