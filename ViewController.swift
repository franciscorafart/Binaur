//
//  ViewController.swift
//  BinaurApp
//
//  Created by Francisco Rafart on 2/1/17.
//  Copyright © 2017 Francisco Rafart. All rights reserved.


//BINAUR is a collective meditation app that uses binaural beats. This is the main view controller of BINAUR app, where individual mmeditation sessions are configured and where the audio process takes place for all the app.  Audio engine built with AudioKit.

import UIKit
import AudioKit

class ViewController: UITableViewController, UIPickerViewDelegate, UINavigationControllerDelegate{

    @IBOutlet weak var headphoneImageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var collectiveButton: UIButton!
    @IBOutlet weak var binaurAppView: UIImageView!
    @IBOutlet weak var myActivityView: UIActivityIndicatorView!
    @IBOutlet weak var initialStateSegmented: UISegmentedControl!
    @IBOutlet weak var targetStateSegmented: UISegmentedControl!
    @IBOutlet weak var myTimePicker: UIDatePicker!
    @IBOutlet weak var myPickerView: UIPickerView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var barraProgreso: UIProgressView!
    @IBOutlet weak var shareButton: UIButton!
    
//    These are global variables for timers for control of duration of sessions, fade in and outs and monitoring the connection of headphones.
    var dataRecieved : Double?
    var timerSecondHeadphones = Timer()
    var timerSecond = Timer()
    var timerRamp = Timer()
    var DuracionMeditacion = 15 //Default 15 minutos duracion
    var duracionMonitor = 15 //Default 15 minutes, same as DuracionMeditation
    var secondCounter = 0
    var minuteCounter = 0
    var pickerData: [String] = [String]()
    let screenSize: CGRect = UIScreen.main.bounds
    
    //Audio Variables
    var mixer : AKMixer!
    var drone : AKAudioPlayer!
    var rotAbsoluta = 0.0
    var myMusicDict = NSDictionary()
    var musicArrayIndex = 0
    var myMusicArray: NSArray?
    var pathMusic = String()
    var sessionSetupComplete = false
    var directionRamp = 0.0 //Audio envelope
    var nombreTema = "Dream.mp3"
    
    //main bundle
    let bundle = Bundle.main

    //Animation variables: For the animation when the audio is active
    var binaurAppAnimation = [UIImage]()
    
//    Binaural variables. 
//    Here are the global variables for controlling oscillator frequencies, amplitudes and durations
    var stimulationFreq = 0.0
    var initialStateFreq = 0.0
    var freqChangeRate = 0.0
    var sine = AKTable(.sine, phase: 4096)
    var oscillator1 = AKOscillator()
    var oscillator2 = AKOscillator()
    var amplitude = 0.0
    var levelBeats = 0.2
  
    //Variables thath controle collective meditation session features
    var collectiveSessionActive = false
    var collectiveTime = 20.0 // 20 minutes duration
    var collectiveFreq = 8.0 //Collective frequency
    var sessionName = ""
    
    //Social media variable: This variable determines weather the possibility of sharing finished sessions is active
    var twitterShare = true
    
    //Play security variable. This variable is to activate or deactivate the Play/Stop button, for moments when the audio is loading.
    var playButtonOn = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Animation arrays and parameters
        for i in 1...2{
            let imageNAme = ("Logo\(i)")
            binaurAppAnimation.append(UIImage(named: imageNAme)!)
        }
        binaurAppView.animationImages = binaurAppAnimation
        binaurAppView.animationDuration = 0.2
        
        
        //Audio array. Variables to acces plist with name of music tracks.
        pathMusic = Bundle.main.path(forResource: "MusicTracks", ofType: "plist")!
        myMusicArray = NSArray(contentsOfFile: pathMusic)
        myMusicDict = myMusicArray![musicArrayIndex] as! NSDictionary //Inicializado en array[0]
    
        
        let arrayCount = (myMusicArray?.count)! - 1
        
        //Here I define the content of the Song Picker picker view from the file MusicTrack.plist
        for i in (0...arrayCount){
            let myMusicDictTemp = myMusicArray![i] as! NSDictionary
            let nameTemp = myMusicDictTemp["Name"] as! String
            pickerData.append(nameTemp)
            print("Name = \(nameTemp)")
            }
        // Connect data:
        myPickerView.delegate = self
        
        //Calling delegate to be able to send data to other view controllers.
        navigationController?.delegate = self
        
        //Headphones connection feedback. 
        //As binaural beats only work with headphones, the app has a headphone connection monitor.
        timerSecondHeadphones = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(headphonePlugged), userInfo: nil, repeats: true) //echar a andar timer para evaluar si headphones estan conectados
        messageLabel.text = "Binaural Beats only work with headphones"
        myTimePicker.countDownDuration = 600
        
        
        //Here I pre-load an audio track in case the user decides to start a session right away without selecting a music track.
        do{
        let droneFile = try AKAudioFile(readFileName: "Dream.mp3", baseDir: .resources)
        drone = try AKAudioPlayer(file: droneFile) {
            print("completion callback has been triggered !")
                                }
        }
            catch _ {return print ("error")}
        
        //Alphas for different views and elements
        binaurAppView.alpha = 0.5
        barraProgreso.alpha = 0
       
        
        //Audio Kit variables
        oscillator1 = AKOscillator(waveform: sine)
        oscillator2 = AKOscillator(waveform: sine)
        oscillator1.amplitude = levelBeats/2
        oscillator2.amplitude = levelBeats/2
        
        //Panning
        let panner1 = AKPanner(oscillator1)
        let panner2 = AKPanner(oscillator2)
        let panner3 = AKPanner(drone)
        
        panner1.pan = 1
        panner2.pan = -1
        
        //No funciona el paneo
        
        drone.looping = true
        drone.volume = 1 - levelBeats //Complemento del LevelBeats
        mixer = AKMixer(panner3, panner1, panner2)

        mixer.volume = 0 //Define initial amplitude of binaural beats
        AudioKit.output = mixer
        AudioKit.start()
        
        //Layout
        myActivityView.isHidden = true
        shareButton.isEnabled = false
        shareButton.alpha = 0.5
        
    }
    override func viewWillAppear(_ animated: Bool) {
        //Evaluar si hay sesion colectiva y poner play. No es necesario. Ya lo hice desde infoViewController
        super.viewWillAppear(true)
    }
    

    //Picker view fucntions
    // The number of columns of data
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        //Here I disable possibility of starting collective session as user modified parameters
        collectiveSessionActive = false
    
        shareButton.isEnabled = false
        shareButton.alpha = 0.5
        
        return pickerData[row]
    }
    
    //Picker View to select background music
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        
    print(" Picker Data Row: \(row) Picker Data Name: \(pickerData[row])")
        myMusicDict = myMusicArray?[row] as! NSDictionary
        nombreTema = "\(myMusicDict["Name"]!).\(myMusicDict["AudioExtension"]!)"
    }

    
    //This function maps a frequency to the user input in the first segmented control in the view controller
    @IBAction func initialSegmentedChange(_ sender: UISegmentedControl) {
    print("\(sender.selectedSegmentIndex)")
        
        //Anular collective session
        collectiveSessionActive = false
        shareButton.isHidden = true
   
        switch sender.selectedSegmentIndex{
        case 0: initialStateFreq = 4 //initialFreqLabel.text = "Sleepy"
            
        case 1: initialStateFreq = 6 //initialFreqLabel.text = "Meditative"
            
        case 2: initialStateFreq = 11 //initialFreqLabel.text = "Relaxed"
            
        case 3: initialStateFreq = 30//initialFreqLabel.text = "Focused"
            
        case 4: initialStateFreq = 45 //initialFreqLabel.text = "Stressed"
            
        default: print ("Default")
        }
    }
    
    //This function maps a frequency to the user input in the second segmented control in the view controller
    @IBAction func targetSegmentedChange(_ sender: UISegmentedControl) {
        
        //Security measure: If a user changes the segmented controller it means they're configuring an individual session, so all the data of a loaded collective meditation session is no considered.
        collectiveSessionActive = false
        shareButton.isHidden = true
        
        print("\(sender.selectedSegmentIndex)")
        
        switch sender.selectedSegmentIndex{
        case 0: stimulationFreq = 4 //targetStateLabel.text = "Sleepy"
            
        case 1: stimulationFreq = 6 //targetStateLabel.text = "Meditative"
            
        case 2: stimulationFreq = 11 //targetStateLabel.text = "Relaxed"
            
        case 3: stimulationFreq = 30 //targetStateLabel.text = "Focused"
            
        default: print ("Default")
        }
        
    }
    
    //This is the first function called when the user hits start session.
    
    @IBAction func startMeditation(_ sender: Any) {

        playButton.isEnabled = false //Security measure: I deactivate the play button immediately. I reactivate it at the end of the RampChange function, when the audio is completely on/off, so the user doesn't press more than one time by accident
        
        self.playButtonOn = !self.playButtonOn //We set the bool PlayButton On to false
        self.waitOn()
        self.play() //This executes the audio process
    }
    
    
    //This Function triggers or stops the audio process
    func play(){
        DispatchQueue.main.async {
            
        let duracionSeconds = Double(self.DuracionMeditacion * 60)
        
        // Play. Security measure in case the user presses the play button twice by accident
        if (self.mixer.volume == 0)&&(self.playButtonOn == true){
            
            
            //Stop audio kit before
            AudioKit.stop()
            
            do{
                let droneFile = try AKAudioFile(readFileName: self.nombreTema, baseDir: .resources)
                
                self.drone = try AKAudioPlayer(file: droneFile) {
                    print("completion callback has been triggered !")}
            }
            catch _ {return print ("error")}
            
            //Levels
            self.oscillator1.amplitude = self.levelBeats*0.5
            self.oscillator2.amplitude = self.levelBeats*0.5
            self.drone.volume = 1 - self.levelBeats //Complemento del LevelBeats
            
            self.mixer = AKMixer(self.drone, self.oscillator1, self.oscillator2)
            self.mixer.volume = 0 //Definir estado inicial de volumen
            AudioKit.output = self.mixer
            AudioKit.start()
            
            // With this code the audio keeps playing when the screen turns off. Activate in Capabilities --> Background modes
            
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch _ {
                return print("error")
            }
            
            //Play audio
            self.drone.play()
            self.drone.looping = true
            self.oscillator1.play()
            self.oscillator2.play()
            
            
            
            //Rate calculation
            self.freqChangeRate = (self.initialStateFreq - self.stimulationFreq)/duracionSeconds //FreqChangeRate es el cambio de frecuencia por segundo definido como la diferencia entre frecuencia inicial y frecuencia final dividida por la duracion de la meditacion en segundos
            
            //Here we define the frequency of the second oscillator, which will create the binaural beats
            self.oscillator2.frequency = 200 + self.initialStateFreq
            self.timerSecond = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.ChangeFreq), userInfo: nil, repeats: true)
            self.directionRamp = 1;
            
            //Activate logo animation for when the audio is running
            self.binaurAppView.startAnimating()
            
            //Seteo el ramp para empezar el audio y visuales
            self.timerRamp = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.ChangeRamp), userInfo: nil, repeats: true)
            
            //Finish wait and reactivate Play Button
            self.waitOff()
            
            
        } else {
            
            print("Wait until play function has finished")
            
            }
        
        // Stop Audio. Security measure in case the user presses twice
                if (self.mixer.volume == 1)&&(self.playButtonOn == false){
            
                        self.timerSecond.invalidate()// Se para desde fuera el timerMinute y Second
            
                        //Ramp elements
                        print("StopAudio was activated already")
                        self.directionRamp = -1;
                        self.timerRamp = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.ChangeRamp), userInfo: nil, repeats: true)
            
                        self.waitOff()
                    
            
                }//inside if statement
                else {
                        print("Wait until it is off")
                        }
            
            //}
        
        
    } //closes async
        
    }
    
    func waitOn(){
       
        myActivityView.startAnimating()
        
        //Display waiting image
        myActivityView.isHidden = false
        
        print("waitOn executed")
    }
    
    func waitOff(){
        
        //stop animation
        if myActivityView.isAnimating{
            myActivityView.stopAnimating()
        }
        //Hide waiting image
        myActivityView.isHidden = true
        
        print("waitOff executed")
    }
    
    
    //With this fucntion we control the fade in and fade out of audio and visual elements on a meditation session
    func ChangeRamp(){
        
        switch directionRamp{
            
        //If directionRamp is 1 it means the audio must fadeIn and session setup visual elements must fade out
        case 1 :
            if (mixer.volume < 1){
  
                //Fade ins
                mixer.volume += 0.05
                binaurAppView.alpha += 0.025
                barraProgreso.alpha += 0.025
                
                //Fade outs
                myPickerView.alpha -= 0.05
                targetStateSegmented.alpha -= 0.05
                myTimePicker.alpha -= 0.05
                initialStateSegmented.alpha -= 0.05
                collectiveButton.alpha -= 0.025
                collectiveButton.isEnabled = false
                

            } else
                if (mixer.volume >= 1){
                    timerRamp.invalidate()
                    
                    //Force 1 values (maximum)
                    mixer.volume = 1 //force 1 when mixer.volume is greater than 1
                    binaurAppView.alpha = 1
                    barraProgreso.alpha = 1
                    playButton.setTitle("Stop Session", for: .normal)
                    
                    
                    
                    //Force 0 values
                    myPickerView.alpha = 0
                    targetStateSegmented.alpha = 0
                    myTimePicker.alpha = 0
                    initialStateSegmented.alpha = 0
                  
                    collectiveButton.alpha = 0.5
                    
                    //Now that all the elements faded in and out, we can change the direction of the ramp
                    directionRamp *= -1
                    
                    //Activate play button again
                    self.playButton.isEnabled = true
            }

        //This is for when the audio must fade out and the setup session UI elements must fade in
        case -1 :
            if (mixer.volume > 0){
                
                //fade outs
                mixer.volume -= 0.05
                binaurAppView.alpha -= 0.025
                barraProgreso.alpha -= 0.025
                
                //Fade ins
                myPickerView.alpha += 0.05
                targetStateSegmented.alpha += 0.05
                myTimePicker.alpha += 0.05
                initialStateSegmented.alpha += 0.05
                collectiveButton.alpha += 0.025
                
                
                
            } else
                //Force 0 value to values below 0
                if (mixer.volume <= 0){
                    timerRamp.invalidate()

                    
                   
                    //Force 0 values
                    mixer.volume = 0 //forzar 0 cuando es menor a 0
                    binaurAppView.alpha = 0.5
                    barraProgreso.alpha = 0
                    
                    //Force 1 values
                    myPickerView.alpha = 1
                    targetStateSegmented.alpha = 1
                    myTimePicker.alpha = 1
                    initialStateSegmented.alpha = 1
                   
                    collectiveButton.alpha = 1
                    collectiveButton.isEnabled = true
                
                    //Change button text
                    playButton.setTitle("Start Session", for: .normal)
                    
                    //Stop audio engine
                    drone.stop()
                    oscillator1.stop()
                    oscillator2.stop()
                    
                    
                
                    //change ramp direction
                    directionRamp *= -1
                    
                    //Activate play button again
                    self.playButton.isEnabled = true
                    
                    //stop animation
                    binaurAppView.stopAnimating()
                    
                    //Allow sharing in social media
                    if (twitterShare == true){
                        
                    shareButton.alpha = 1
                    shareButton.isEnabled = true
                    }
                    
                    
        
                        
 
            }//closes if mixer.volume<=0
            
        default : print("Anything")
        } //closes switch directionRampo
    }
    
    //This function changes the frequency according to a delta (freqChangeRate) every time it is called, as well as changin counters and progress bar
    func ChangeFreq(){
        oscillator2.frequency -= freqChangeRate
        
        let deltaBarra = Float(1.0/(Float(DuracionMeditacion)*60.0))
        barraProgreso.progress += deltaBarra
        
        if (secondCounter == 59){
            changeLabel()
            secondCounter = 0
            minuteCounter += 1
            
        } else {
            secondCounter += 1;
            if minuteCounter >= DuracionMeditacion{
                StopAudio1()
            }
        }
    }
    
    //Function to change timing label
    func changeLabel(){
        duracionMonitor -= 1
        messageLabel.text = "\(duracionMonitor) minutes left"
    }
    
    //Function that stops audio
    func StopAudio1(){
            
            timerSecond.invalidate()
            binaurAppView.stopAnimating()
        
            //Ramp stuff (esto comienza el proceso de apagado con dirrecion -1)
            directionRamp = -1;
            timerRamp = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ChangeRamp), userInfo: nil, repeats: true)
        
        collectiveSessionActive = false
        duracionMonitor = DuracionMeditacion
    }
    
    //
    @IBAction func TimerChanged(_ sender: UIDatePicker) {
        print("Countdown Value = \(myTimePicker.countDownDuration.value())")
        DuracionMeditacion = Int(myTimePicker.countDownDuration.value()/60.0)
        duracionMonitor = DuracionMeditacion
        collectiveSessionActive = false
        barraProgreso.progress = 0
    }

    //Prepare segue to go to other View Controllers and pass variables
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.identifier == "pushToSettings" {
            let viewControllerB = segue.destination as! SettingsTableViewController
            
            viewControllerB.amplitude = levelBeats
            print("level Beats = \(levelBeats)")
            viewControllerB.isTwitterOn = twitterShare
            print("Twitter Share = \(twitterShare)")
        } else {
        //segue a CollectiveMeditation
            if segue.identifier == "pushToCollective"{
            let viewControllerC = segue.destination as! CollectiveMeditationViewController
                viewControllerC.collectiveSessionBool = collectiveSessionActive
            }
        }
        
        
        
        
        
    }
    
    //Function that is called regulary to check the user has headphones connected
    func headphonePlugged(){
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        if currentRoute.outputs.isEmpty == false {
            for description in currentRoute.outputs {
                if description.portType == AVAudioSessionPortHeadphones {//If estan conectados
                    
                    //We execute this code only when there's a change. Set animation only when headphones are connected again.
                    if headphoneImageView.isHidden == false{
                        headphoneImageView.isHidden = true
                        messageLabel.text = ""
                        
                } else {
                    headphoneImageView.isHidden = true
                        }
                } else{
                    headphoneImageView.isHidden = false
                }
            }
        }

    }
    
    
    //Share on social media function
    @IBAction func sharePressed(_ sender: UIButton) {
        
        //Social media share
        if (twitterShare == true){
            
            var shareText = String()
            
            if collectiveSessionActive == true {
                shareText = "I just joined a \(DuracionMeditacion) minute collective #binuarlbeats session named \(sessionName), using #BINAUR. http://www.rafartmusic.com/binaur/"
            } else{
                shareText = "I just finished a \(DuracionMeditacion) minute #binuarlbeats conciousness shifting session using #BINAUR. http://www.rafartmusic.com/binaur/"
            }
            
            
            //let stringURL = "http://www.rafartmusic.com/binaur/"
            
            //let appURL = NSURL(fileURLWithPath: stringURL, isDirectory: false)
            if let thisImage = UIImage(named: "Logo2.png"){
                
                let vc = UIActivityViewController(activityItems: [shareText, thisImage], applicationActivities: [])
                present(vc, animated: true)
            }
            
        }
        
    }
    
    
}
