//
//  TButtonExtension.swift
//  Telereso
//
//  Created by Ganesh TR on 04/05/22.
//

import SDWebImage

extension UIButton {

    public func setRemoteImageWith(key: String, for state: UIControl.State) {
        guard let url = Telereso.getRemoteDrawable(key: key) else {
            self.setImage(UIImage(named:key), for: state)
            return
        }
        sd_setImage(with: url, for: state, placeholderImage: nil, options: [.highPriority, .avoidAutoSetImage, .fromCacheOnly]) { [weak self] cachedImage, error, cacheType, url in
            if let image = cachedImage, error == nil {
                self?.setImage(image, for: state)
                return
            }
            self?.sd_setImage(with: url, for: state, placeholderImage: UIImage(named:key), options: [.highPriority, .scaleDownLargeImages])
        }
    }

    public func setRemoteBackgroundImageWith(key: String, for state: UIControl.State) {
        guard let url = Telereso.getRemoteDrawable(key: key) else {
            self.setBackgroundImage(UIImage(named:key), for: state)
            return
        }
        sd_setBackgroundImage(with: url, for: state, placeholderImage: nil, options: [.highPriority, .avoidAutoSetImage, .fromCacheOnly]) { [weak self] cachedImage, error, cacheType, url in
            if let image = cachedImage, error == nil {
                self?.setImage(image, for: state)
                self?.setBackgroundImage(image, for: state)
                return
            }
            self?.sd_setBackgroundImage(with: url, for: state, placeholderImage: UIImage(named:key), options: [.highPriority, .scaleDownLargeImages])
        }
    }
}
