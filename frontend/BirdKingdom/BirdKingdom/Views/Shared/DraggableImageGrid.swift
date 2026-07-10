//
//  DraggableImageGrid.swift
//  BirdKingdom
//
//  简约高级感可拖拽排序图片网格组件
//

import SwiftUI
import PhotosUI

// MARK: - 可拖拽排序的图片网格
struct DraggableImageGrid: View {
    @Binding var images: [UIImage]
    let maxImages: Int
    let primaryColor: Color
    @Binding var selectedItems: [PhotosPickerItem]
    
    @State private var showActionSheet = false
    @State private var showPhotoLibrary = false
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images.indices, id: \.self) { index in
                    draggableImageItem(index: index)
                }
                
                if images.count < maxImages {
                    addImageButton
                }
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $cameraImage)
        }
        // 修复：显式使用 photosPicker
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedItems, maxSelectionCount: maxImages - images.count, matching: .images)
        .confirmationDialog(NSLocalizedString("添加图片", comment: ""), isPresented: $showActionSheet, titleVisibility: .visible) {
            Button(NSLocalizedString("从相册选择", comment: "")) {
                showPhotoLibrary = true
            }
            Button(NSLocalizedString("拍摄照片", comment: "")) {
                showCamera = true
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                withAnimation(.easeOut(duration: 0.2)) {
                    images.append(image)
                }
                cameraImage = nil
            }
        }
    }
    
    // ... draggableImageItem 保持不变 ...
    // MARK: - 可拖拽的图片项
    private func draggableImageItem(index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            draggingIndex == index ? primaryColor : Color.clear,
                            lineWidth: 2
                        )
                )
            
            // 删除按钮
            Button {
                HapticFeedback.light()
                withAnimation(.easeOut(duration: 0.2)) {
                    _ = images.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, Color.black.opacity(0.5))
            }
            .offset(x: 6, y: -6)
        }
        .opacity(draggingIndex == index ? 0.7 : 1.0)
        .scaleEffect(draggingIndex == index ? 1.05 : 1.0)
        .offset(draggingIndex == index ? dragOffset : .zero)
        .zIndex(draggingIndex == index ? 1 : 0)
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture())
                .onChanged { value in
                    switch value {
                    case .first(true):
                        withAnimation(.easeOut(duration: 0.2)) {
                            draggingIndex = index
                        }
                        HapticFeedback.medium()
                    case .second(true, let drag):
                        if let drag = drag {
                            dragOffset = drag.translation
                            
                            let itemWidth: CGFloat = 90
                            let dragDistance = drag.translation.width
                            let targetIndex = index + Int(round(dragDistance / itemWidth))
                            
                            if targetIndex >= 0 && targetIndex < images.count && targetIndex != index {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    images.swapAt(index, targetIndex)
                                    draggingIndex = targetIndex
                                    dragOffset = .zero
                                }
                                HapticFeedback.selection()
                            }
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        draggingIndex = nil
                        dragOffset = .zero
                    }
                }
        )
        .animation(.easeOut(duration: 0.2), value: draggingIndex)
    }
    
    // MARK: - 添加图片按钮
    private var addImageButton: some View {
        Button {
            showActionSheet = true
        } label: {
            addButtonContent
        }
    }
    
    private var addButtonContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .foregroundColor(primaryColor.opacity(0.5))
            
            RoundedRectangle(cornerRadius: 12)
                .fill(primaryColor.opacity(0.05))
            
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(primaryColor)
                
                Text(NSLocalizedString("添加", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(primaryColor.opacity(0.8))
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - 简化版拖拽图片网格
struct SimpleDraggableImageGrid: View {
    @Binding var images: [UIImage]
    let primaryColor: Color
    var onAddTapped: (() -> Void)?
    var showAddButton: Bool = true
    var maxImages: Int = 9
    
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images.indices, id: \.self) { index in
                    draggableImageItem(index: index)
                }
                
                if showAddButton && images.count < maxImages {
                    addButton
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func draggableImageItem(index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            draggingIndex == index ? primaryColor : Color.clear,
                            lineWidth: 2
                        )
                )
            
            Button {
                HapticFeedback.light()
                withAnimation(.easeOut(duration: 0.2)) {
                    _ = images.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, Color.black.opacity(0.5))
            }
            .offset(x: 6, y: -6)
        }
        .opacity(draggingIndex == index ? 0.7 : 1.0)
        .scaleEffect(draggingIndex == index ? 1.05 : 1.0)
        .offset(draggingIndex == index ? dragOffset : .zero)
        .zIndex(draggingIndex == index ? 1 : 0)
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture())
                .onChanged { value in
                    switch value {
                    case .first(true):
                        withAnimation(.easeOut(duration: 0.2)) {
                            draggingIndex = index
                        }
                        HapticFeedback.medium()
                    case .second(true, let drag):
                        if let drag = drag {
                            dragOffset = drag.translation
                            
                            let itemWidth: CGFloat = 90
                            let dragDistance = drag.translation.width
                            let targetIndex = index + Int(round(dragDistance / itemWidth))
                            
                            if targetIndex >= 0 && targetIndex < images.count && targetIndex != index {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    images.swapAt(index, targetIndex)
                                    draggingIndex = targetIndex
                                    dragOffset = .zero
                                }
                                HapticFeedback.selection()
                            }
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        draggingIndex = nil
                        dragOffset = .zero
                    }
                }
        )
        .animation(.easeOut(duration: 0.2), value: draggingIndex)
    }
    
    private var addButton: some View {
        Button {
            HapticFeedback.light()
            onAddTapped?()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .foregroundColor(primaryColor.opacity(0.5))
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(primaryColor.opacity(0.05))
                
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(primaryColor)
                    
                    Text(NSLocalizedString("添加", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(primaryColor.opacity(0.8))
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}
