import SwiftUI
import MapKit

// MARK: - 位置选择结果
struct SelectedLocation {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - 地图位置搜索选择器
struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var locationService = LocationService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedMapItem: MKMapItem?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showConfirmation = false
    @State private var searchTask: Task<Void, Never>? = nil  // 用于防抖动
    
    let useCurrentLocation: Bool  // 是否使用当前定位预填充
    let onLocationSelected: (SelectedLocation) -> Void
    
    init(useCurrentLocation: Bool = true, onLocationSelected: @escaping (SelectedLocation) -> Void) {
        self.useCurrentLocation = useCurrentLocation
        self.onLocationSelected = onLocationSelected
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 地图视图
                Map(position: $cameraPosition, selection: $selectedMapItem) {
                    // 显示搜索结果标记
                    ForEach(searchResults, id: \.self) { item in
                        if let coordinate = item.placemark.location?.coordinate {
                            Marker(item.name ?? NSLocalizedString("位置", comment: ""), coordinate: coordinate)
                                .tint(primaryColor)
                        }
                    }
                    
                    // 显示选中的位置
                    if let selected = selectedMapItem,
                       let coordinate = selected.placemark.location?.coordinate {
                        Annotation(selected.name ?? NSLocalizedString("选中位置", comment: ""), coordinate: coordinate) {
                            ZStack {
                                Circle()
                                    .fill(primaryColor)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "mappin")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .ignoresSafeArea(edges: .bottom)
                
                // 搜索栏和结果列表
                VStack(spacing: 0) {
                    // 搜索栏
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField(NSLocalizedString("搜索地址，如：北京市朝阳区xxx小区", comment: ""), text: $searchText)
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .onSubmit {
                                searchLocation()
                            }
                            .onChange(of: searchText) { oldValue, newValue in
                                // 取消之前的搜索任务
                                searchTask?.cancel()
                                
                                if newValue.isEmpty {
                                    searchResults = []
                                    selectedMapItem = nil
                                    return
                                }
                                
                                // 防抖动：延迟0.5秒后搜索
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    if !Task.isCancelled && newValue.count >= 2 {
                                        await MainActor.run {
                                            searchLocation()
                                        }
                                    }
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(12)
                    .background(Color.adaptiveCard)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // 搜索结果列表
                    if !searchResults.isEmpty {
                        KeyboardDismissScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button {
                                        selectLocation(item)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(primaryColor)
                                                .font(.title2)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name ?? NSLocalizedString("未知地点", comment: ""))
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                Text(formatAddress(item.placemark))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedMapItem == item {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(primaryColor)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(selectedMapItem == item ? primaryColor.opacity(0.1) : Color.white)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                        .background(Color.adaptiveCard)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // 底部确认按钮
                    if let selected = selectedMapItem {
                        VStack(spacing: 12) {
                            // 选中位置信息
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(primaryColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.name ?? NSLocalizedString("选中位置", comment: ""))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(formatAddress(selected.placemark))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.adaptiveCard)
                            .cornerRadius(12)
                            
                            // 确认按钮
                            Button {
                                confirmSelection()
                            } label: {
                                Text(NSLocalizedString("确认选择此位置", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(primaryColor)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(16)
                        .background(Color.adaptiveCard)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("选择位置", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(primaryColor.opacity(0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(primaryColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .foregroundColor(primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 使用当前定位
                        applyCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundColor(primaryColor)
                    }
                }
            }
        }
        .onAppear {
            // 根据useCurrentLocation决定是否预填充当前位置
            if useCurrentLocation, let location = locationService.currentLocation {
                print("📍 地图初始化（当前定位模式）：\(location.coordinate.latitude), \(location.coordinate.longitude)")
                
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
                
                // 反向地理编码获取详细地址并显示在搜索框
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemark = placemarks?.first {
                        // 构建详细地址
                        var addressComponents: [String] = []
                        if let administrativeArea = placemark.administrativeArea {
                            addressComponents.append(administrativeArea)
                        }
                        if let locality = placemark.locality, locality != placemark.administrativeArea {
                            addressComponents.append(locality)
                        }
                        if let subLocality = placemark.subLocality {
                            addressComponents.append(subLocality)
                        }
                        if let thoroughfare = placemark.thoroughfare {
                            addressComponents.append(thoroughfare)
                        }
                        if let subThoroughfare = placemark.subThoroughfare {
                            addressComponents.append(subThoroughfare)
                        }
                        if let name = placemark.name, !addressComponents.contains(name) {
                            addressComponents.append(name)
                        }
                        
                        let fullAddress = addressComponents.joined(separator: "")
                        print("📍 反向地理编码成功：\(fullAddress)")
                        
                        // 在搜索框显示详细地址
                        searchText = fullAddress
                        
                        // 创建MKMapItem作为选中项
                        let mkPlacemark = MKPlacemark(placemark: placemark)
                        let mapItem = MKMapItem(placemark: mkPlacemark)
                        mapItem.name = placemark.name ?? NSLocalizedString("当前位置", comment: "")
                        selectedMapItem = mapItem
                        searchResults = [mapItem]
                    } else {
                        print("📍 反向地理编码失败：\(error?.localizedDescription ?? "未知错误")")
                        if !locationService.fullAddress.isEmpty {
                            searchText = locationService.fullAddress
                        }
                    }
                }
            } else if !useCurrentLocation {
                // 手动输入模式：地图定位到当前位置但搜索框为空
                print("📍 地图初始化（手动输入模式）：搜索框为空")
                if let location = locationService.currentLocation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            } else {
                print("📍 地图初始化：没有当前位置，请求定位")
                locationService.startLocating()
            }
        }
    }
    
    // 搜索位置
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        print("🔍 开始搜索位置: \(searchText)")
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]
        
        // 扩大搜索范围到全国
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0), // 中国中心
            span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 60.0)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let error = error {
                    print("❌ 搜索位置失败: \(error.localizedDescription)")
                    return
                }
                
                if let items = response?.mapItems {
                    print("✅ 搜索到 \(items.count) 个结果")
                    searchResults = items
                    
                    // 如果有结果，自动选中第一个并移动地图
                    if let first = items.first,
                       let coordinate = first.placemark.location?.coordinate {
                        print("📍 移动地图到: \(first.name ?? "未知"), 坐标: \(coordinate.latitude), \(coordinate.longitude)")
                        selectedMapItem = first
                        withAnimation {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            ))
                        }
                    }
                } else {
                    print("⚠️ 没有搜索到结果")
                }
            }
        }
    }
    
    // 选择位置
    private func selectLocation(_ item: MKMapItem) {
        selectedMapItem = item
        
        // 移动地图到选中位置
        if let coordinate = item.placemark.location?.coordinate {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
    
    // 使用当前定位按钮点击
    private func applyCurrentLocation() {
        guard let location = locationService.currentLocation else {
            locationService.startLocating()
            return
        }
        
        // 反向地理编码获取地址
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let selectedLocation = SelectedLocation(
                    name: locationService.shortAddress,
                    address: locationService.fullAddress,
                    coordinate: location.coordinate
                )
                onLocationSelected(selectedLocation)
                dismiss()
            }
        }
    }
    
    // 确认选择
    private func confirmSelection() {
        guard let item = selectedMapItem,
              let coordinate = item.placemark.location?.coordinate else { return }
        
        let selectedLocation = SelectedLocation(
            name: item.name ?? NSLocalizedString("选中位置", comment: ""),
            address: formatAddress(item.placemark),
            coordinate: coordinate
        )
        
        onLocationSelected(selectedLocation)
        dismiss()
    }
    
    // 格式化地址
    private func formatAddress(_ placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let country = placemark.country {
            // 不显示中国
            if country != NSLocalizedString("中国", comment: "") && country != "China" {
                components.append(country)
            }
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let locality = placemark.locality, locality != placemark.administrativeArea {
            components.append(locality)
        }
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        
        return components.joined(separator: "")
    }
}

#Preview {
    MapLocationPickerView(onLocationSelected: { location in
        print("选中位置: \(location.name), \(location.address), \(location.coordinate)")
    })
}
