//
//  TImageViewExtension.swift
//  Telereso
//
//  Created by Ganesh TR on 04/05/22.
//

extension UIImageView {
    public func setRemoteImageWith(key: String, placeholderImage: String? = nil) {
        guard let url = Telereso.getRemoteDrawable(key: key) else {
            self.image = UIImage(named:placeholderImage ?? key)
            return
        }
        sd_setImage(
            with: url,
            placeholderImage: nil,
            options: [.highPriority, .avoidAutoSetImage, .fromCacheOnly]) { [weak self] (cachedImage, error, cacheType, url) in
                if let image = cachedImage, error == nil {
                    self?.image = image
                    return
                }
                self?.sd_setImage(with: url, placeholderImage: UIImage(named:placeholderImage ?? key),
                                  options: [.highPriority, .scaleDownLargeImages])
            }
    }
}
