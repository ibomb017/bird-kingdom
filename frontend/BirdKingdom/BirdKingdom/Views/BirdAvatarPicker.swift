import SwiftUI
import PhotosUI

struct BirdAvatarPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 当前头像预览
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(forestGreen, lineWidth: 3)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(forestGreen.opacity(0.1))
                            .frame(width: 200, height: 200)
                        
                        Image(systemName: "bird.fill")
                            .font(.system(size: 80))
                            .foregroundColor(forestGreen.opacity(0.5))
                    }
                }
                
                // 选择照片按钮
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选择")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(forestGreen)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }
                
                // 拍照按钮
                Button {
                    // TODO: 打开相机
                } label: {
                    HStack {
                        Image(systemName: "camera")
                        Text("拍摄照片")
                    }
                    .font(.headline)
                    .foregroundColor(forestGreen)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(forestGreen, lineWidth: 2)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("选择头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(forestGreen)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(forestGreen)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
