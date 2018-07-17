//
//  ViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/12.
//  Copyright © 2018年 Darko. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var inputImageView: UIImageView!
    
    let input = UIImage(named: "sample.png")!
    
    @IBAction func setSRImageButtionDidTap(_ sender: Any) {
        inputImageView.setSRImage(image: input)
    }
    
    @IBAction func resetButtionDidTap(_ sender: Any) {
        inputImageView.image = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
