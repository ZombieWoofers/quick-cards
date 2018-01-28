//
//  ViewController.swift
//  CardGenerator
//
//  Created by AG on 11/6/17.
//  Copyright © 2017 Geisthardt Inc. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, UIDocumentPickerDelegate, NSFilePresenter, AVSpeechSynthesizerDelegate {
    
    var presentedItemURL: URL?
    var presentedItemOperationQueue = OperationQueue()
    
    let documentPicker = UIDocumentPickerViewController.init(documentTypes: ["public.data"], in: UIDocumentPickerMode.open)
    
    var isICloudEnabled = true
    var list = [String]()
    var categoryList = [String]()
    var tempList = [String]()
    var wrongList = [String]()
    var studyWrongs = false
    
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var categoryButton: UIButton!
    
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var autoPlayButton: UIButton!
    @IBOutlet weak var reverseButton: UIButton!
    
    @IBOutlet weak var totalTerms: UILabel!
    
    @IBOutlet weak var rightCount: UILabel!
    @IBOutlet weak var wrongCount: UILabel!
    
    @IBOutlet weak var right: UIButton!
    @IBOutlet weak var wrong: UIButton!
    
    @IBOutlet weak var listCollectionView: UICollectionView!
    let defaultFlowLayout = UICollectionViewFlowLayout()
    let nibCellName = "CategoryCell"
    // UICollectionViewDelegate
    // UICollectionViewDataSource
    
    @IBOutlet weak var labelOne: UILabel!
    @IBOutlet weak var labelTwo: UILabel!
    
    var index = 0
    var reversed = false
    var isAutoPlay = false
    var isSpeechEnabled = false
    
    // http://nshipster.com/avspeechsynthesizer/
    let speechSynthesizer = AVSpeechSynthesizer.init()
    
    let voiceLanguage = AVSpeechSynthesisVoice.init(language: "ru-RU")
    let nativeLanguage = AVSpeechSynthesisVoice.init(language: "en-US")
    let speechRate: Float = 0.4

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        //fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        documentPicker.delegate = self
        NSFileCoordinator.addFilePresenter(self)
        
        speechSynthesizer.delegate = self

        let tapGestureAddSquare = UITapGestureRecognizer(target:self, action:#selector(tapGestureMethod))
        tapGestureAddSquare.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGestureAddSquare)
        
        labelOne.layer.borderWidth = 1.0
        labelTwo.layer.borderWidth = 1.0
        
        labelOne.isHidden = true
        labelTwo.isHidden = true
        
        right.isHidden = true
        wrong.isHidden = true
        rightCount.isHidden = true
        wrongCount.isHidden = true
        
        // doesn't work :\
        documentPicker.allowsMultipleSelection = true
 
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        
        if list.isEmpty {
            muteButton.isHidden = true
            autoPlayButton.isHidden = true
            reverseButton.isHidden = true
        } else {
            resetList()
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeSpokenAudio, options: [])
        } catch let error as NSError {
            print("Failed to set the audio session category and mode: \(error.localizedDescription)")
        }
        
    }
    
    @objc func tapGestureMethod() {
        
        //index += 1
        //loadTerms()
    }
    
    @IBAction func mute(sender: UIButton) {
        if sender.isSelected {
            sender.isSelected = false
            isSpeechEnabled = false
        } else {
            sender.isSelected = true
            isSpeechEnabled = true
            if labelOne.isHidden {
                speakBack()
            } else {
                speakFront()
            }
        }
    }
    
    @IBAction func autoPlay(sender: UIButton) {
        if sender.isSelected {
            sender.isSelected = false
            isAutoPlay = false
        } else {
            sender.isSelected = true
            isAutoPlay = true
            autoFlipWithSpeech()
        }
    }
    
    @IBAction func reverse() {
        reversed = reversed ? false : true
        showAnswer()
    }
    
    @IBAction func showAnswer() {
        
        if UIApplication.shared.applicationState != UIApplicationState.active {
            return
        }
        
        
        if reversed {
            labelOne.isHidden = false
        } else {
            labelTwo.isHidden = false
        }
        
        return
        
        if reversed {

            if labelTwo.isHidden {  // if we're looking at answer, flip back
                labelOne.isHidden = true
                labelTwo.isHidden = false
                if isSpeechEnabled && !isAutoPlay {
                    speakBack()
                }
            } else {
                labelOne.isHidden = false
                labelTwo.isHidden = true
                if isSpeechEnabled && !isAutoPlay {
                    speakFront()
                }
            }
        } else {

            if labelOne.isHidden {  // if we're looking at answer, flip back
                labelOne.isHidden = false
                labelTwo.isHidden = true
                if isSpeechEnabled && !isAutoPlay {
                    speakFront()
                }
            } else {
                labelOne.isHidden = true
                labelTwo.isHidden = false
                if isSpeechEnabled && !isAutoPlay {
                    speakBack()
                }
            }
        }
    }
    
    @IBAction func correct() {
        
        let answer = labelOne.text! + "," + labelTwo.text!
        
        var count = Int(rightCount.text!)!
        count += 1
        rightCount.text = String(count)
        
        if wrongList.count > 0 {
            for (i,value) in wrongList.enumerated() { // quick n dirty
                if value == answer {
                    wrongList.remove(at: i)
                    index = i
                    loadTerms()
                    break
                }
            }
        }
        
        index += 1
        loadTerms()
    }
    
    @IBAction func inCorrect() {
        let wrongAnswer = labelOne.text! + "," + labelTwo.text!
        
        var count = Int(wrongCount.text!)!
        count += 1
        wrongCount.text = String(count)
        
        index += 1
        
        for i in wrongList { // quick n dirty
            if i == wrongAnswer {
                loadTerms()
                break
            }
        }
        
        wrongList.append(wrongAnswer)
        loadTerms()
    }
    
    @IBAction func showDocumentPicker() {
        // do they have iCloud enabled??
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    // MARK: UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        // app must perform all file read and write operations using file coordination.
        // If you display the contents of the document to the user, you must track the document’s state using a file presenter.
        
        // If you are using a UIDocument subclass, it will automatically consume the security-scoped URLs for you
        
        print("picked document: \(urls[0].absoluteString)")
        
        if urls[0].startAccessingSecurityScopedResource() {
            parseFile(path: urls[0].path)
            loadTerms()
            
            muteButton.isHidden = false
            autoPlayButton.isHidden = false
            reverseButton.isHidden = false
            
        } else {
            print("startAccessingSecurityScopedResource FAILED!")
        }
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("cancelled")
        // loadTerms()
    }
    
    private func parseFile(path: String) {
        
        if FileManager.default.fileExists(atPath: path) {
            guard let data = FileManager.default.contents(atPath: path) else {
                print("File failed to open!"); return
            }

            // let pathName = path.components(separatedBy: "/")
            // let fileName = pathName[pathName.count - 1]

            if let s = String(data: data, encoding: String.Encoding.utf8) {
                
                self.rightCount.text = "0"
                self.wrongCount.text = "0"

                list.removeAll()
                list = s.components(separatedBy: "\n");
                // list.append(contentsOf: lines)
                
                right.isHidden = false
                wrong.isHidden = false
                rightCount.isHidden = false
                wrongCount.isHidden = false
                
                totalTerms.text = "\(list.count) Terms"
                
            } else {
                print("convert FAIL!")
            }
        } else {
            print("cannot find file!")
        }
    }

    private func setOrder() {
    
        if reversed {
            labelOne.isHidden = true
            labelTwo.isHidden = false
        } else {
            labelOne.isHidden = false
            labelTwo.isHidden = true
        }
    }
    
    
    private func loadTerms() {
        
        if UIApplication.shared.applicationState != UIApplicationState.active {
            return
        }
        
        setOrder() // button state instead?
        
        tempList = list
        
        if index == tempList.count { // start over
            
            let total = Int(rightCount.text!)! + Int(wrongCount.text!)!
            let score = rightCount.text! + " out of " + String(total)
            
            let alert = UIAlertController.init(title: "Done!", message: score, preferredStyle: .alert)
            
            let again = UIAlertAction.init(title: "Start Over", style: UIAlertActionStyle.default, handler: {(_) in
                self.rightCount.text = "0"
                self.wrongCount.text = "0"
                self.resetList()
                alert.dismiss(animated: true, completion: nil)
            })
            
            alert.addAction(again)
            
            self.present(alert, animated: true, completion: nil)
            index = 0
            
        } else {
            resetList()
        }
    }
    
    
    private func russianStressMarks(word: String) -> String {
        
        if let char = word.index(of: "*") {
            let previousIndex = word.index(before: char)
            let stressedCharacter = word[previousIndex]
            print("\(stressedCharacter)") // this is our stress mark
            return word.replacingOccurrences(of: "*", with: "") // ´
            
        } else {
            var updatedWord = word
            
            if word.contains("á") {
                updatedWord = word.replacingOccurrences(of: "á", with: "а") // ´
            }
            
            if word.contains("ó") {
                updatedWord = word.replacingOccurrences(of: "ó", with: "о") // ´
            }
            
            if word.contains("é") {
                updatedWord = word.replacingOccurrences(of: "é", with: "е") // ´
            }
            
            return updatedWord
        }
    }
    
    
    private func resetList() {
        
        if tempList[index].contains(",") {
            
            let line = tempList[index].components(separatedBy: ",")
            
            var text1 = line[0]
            var text2 = line[1]
            
            if text1.contains("*") { // Russian
                text1 = russianStressMarks(word: text1)
            }
            
            if text2.contains("*") { // Russian
                text2 = russianStressMarks(word: text2)
            }

            let blue = UIColor.blue
            let black = UIColor.black
            
            labelOne.text = text1
            labelTwo.text = text2
            
            labelOne.textColor = reversed ? black : blue
            labelTwo.textColor = reversed ? blue : black
            
            if isSpeechEnabled {
                if reversed {
                    speakBack()
                } else {
                    speakFront()
                }
            }
            
            if reversed {
                labelOne.isHidden = true
            } else {
                labelTwo.isHidden = true
            }
            
        } else {
            index += 1
            loadTerms()
        }
    }
    
    private func autoFlipWithSpeech() {
        if reversed {
            speakBack()
        } else {
            speakFront()
        }
    }
    
    @objc private func speakFront() {
        
        let line = tempList[index].components(separatedBy: ",")
        
        let text = line[0]

        let speechUtterance = AVSpeechUtterance.init(string: russianStressMarks(word: text))
        speechUtterance.voice = reversed ? nativeLanguage : voiceLanguage
        speechUtterance.rate = speechRate
        
        speechSynthesizer.speak(speechUtterance)
        
        if reversed && isAutoPlay {
            index += 1
        }
    }
    
    @objc private func speakBack() {
        
        let line = tempList[index].components(separatedBy: ",")
        let text = line[1]
        let speechUtterance = AVSpeechUtterance.init(string: text)
        
        speechUtterance.voice = reversed ? voiceLanguage : nativeLanguage
        speechUtterance.rate = speechRate
        
        speechSynthesizer.speak(speechUtterance)
        
        if !reversed && isAutoPlay {
            index += 1
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        
    }
    
    @available(iOS 7.0, *)
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {

        if isAutoPlay {
            
            if index == tempList.count {
                return
            }
            
            let line = tempList[index].components(separatedBy: ",")
            
            if utterance.speechString == russianStressMarks(word: line[0]) {
                _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(speakBack), userInfo: nil, repeats: false)
                // showAnswer()
            } else {
                // loadTerms()
                _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(speakFront), userInfo: nil, repeats: false)
            }
        }
    }
    
    @available(iOS 7.0, *)
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        
    }
    
    @available(iOS 7.0, *)
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        
    }
    
    @available(iOS 7.0, *)
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        
    }
    
    
    @available(iOS 7.0, *)
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        
    }
    
    
    // TBD on use here
    @IBAction func showCategories() {
        
        let alert = UIAlertController.init(title: "Choose a Category", message: "", preferredStyle: .actionSheet)
        
        let loadNewCategory = { [weak self] (selectedIndex: Int) in
            let category = self?.categoryList[selectedIndex]
            self?.categoryLabel.text = category?.components(separatedBy: "::")[0]
            // self?.loadTerms(categoryIndex: selectedIndex)
        }
        
        for (index, value) in categoryList.enumerated() {
            let title = value.components(separatedBy: ",")[0]
            let action = UIAlertAction.init(title: title, style: UIAlertActionStyle.default, handler: {(_) in
                loadNewCategory(index)
            })
            alert.addAction(action)
        }
        
        let cancel = UIAlertAction.init(title: "Cancel", style: UIAlertActionStyle.cancel, handler: {(_) in
            alert.dismiss(animated: true, completion: nil)
        })
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

