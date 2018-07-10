//
//  UIImageView+SRCNN.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/4.
//  Copyright © 2018年 Darko. All rights reserved.
//

import UIKit

extension UIImageView {
    public func setSRImage(image src: UIImage) {
        self.image = src
        DispatchQueue.global().async { [weak self] in
            if let output = SRCNNModel.shared.convert(from: src) {
                DispatchQueue.main.async {
                    self?.image = output
                    self?.layer.add(CATransition(), forKey: nil)
                }
            }
        }
    }
}
