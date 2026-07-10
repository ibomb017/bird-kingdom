import UIKit
import ImageIO

extension UIImage {
    /// 使用 ImageIO 高效降采样图片数据，避免将完整大图加载到内存中
    /// - Parameters:
    ///   - imageData: 原始图片数据
    ///   - maxDimension: 最大边长 (默认 1500)
    ///   - scale: 屏幕缩放因子 (默认 1.0，如果是用于显示建议传 UIScreen.main.scale)
    /// - Returns: 降采样后的 UIImage
    static func downsample(from imageData: Data, toMaxDimension maxDimension: CGFloat = 1500, scale: CGFloat = 1.0) -> UIImage? {
        // 创建图像源选项，防止自动解码
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return nil
        }
        
        // 缩略图生成选项
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true, // 立即解码，避免在渲染时卡顿
            kCGImageSourceCreateThumbnailWithTransform: true, // 自动处理方向
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        
        // 生成缩略图 (只会解码目标尺寸的像素，极大节省内存)
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage, scale: scale, orientation: .up)
    }
    
    /// (旧方法保留但推荐使用上面的静态方法) 将图片调整到指定的最大边长
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let originalSize = self.size
        let aspectRatio = originalSize.width / originalSize.height
        
        var newSize: CGSize
        if originalSize.width > originalSize.height {
            let newWidth = min(originalSize.width, maxDimension)
            let newHeight = newWidth / aspectRatio
            newSize = CGSize(width: newWidth, height: newHeight)
        } else {
            let newHeight = min(originalSize.height, maxDimension)
            let newWidth = newHeight * aspectRatio
            newSize = CGSize(width: newWidth, height: newHeight)
        }
        
        if originalSize.width <= newSize.width && originalSize.height <= newSize.height {
            return self
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
