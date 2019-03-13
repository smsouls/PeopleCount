//
//  ViewController.swift
//  PeopleCount
//
//  Created by 123 on 2019/3/12.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var queryButton: UIButton!
    @IBOutlet weak var jobNameTextField: UITextField!
    @IBOutlet weak var noTextField: UITextField!
    @IBOutlet weak var resultBoardLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    
    let requestUrl = URLRequest.init(url: (URL.init(string: "http://www.fjkl.gov.cn/signupcount"))!)
    var jobs = NSMutableArray.init()
    let semaphore =  DispatchSemaphore(value: 0)
    let topJobs = NSMutableArray.init(capacity: 5)
    var maxSignPeople: NSArray!
    var totalPeoples = 0.0 //报名总人数
    var totalPassPeoples = 0.0 //总的通过审核的人数
    var totalPositions = 0.0 //总的职位数
    var totalJobs = 0.0 //总的录取人数
    
    func reset() {
        totalPeoples = 0.0
        totalPassPeoples = 0.0
        totalPositions = 0.0
        totalJobs = 0.0
        
        maxSignPeople = nil
        topJobs.removeAllObjects()
        jobs.removeAllObjects()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        doRequest()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: 1100)
        DispatchQueue.global().async {
            _ = self.semaphore.wait(timeout: .distantFuture)
            var resultText = self.selectJob("07725", "计算机")
            
            self.top5Jobs()
            resultText = resultText + "\n\n包名人最多的岗位为\n" + "组织为:" + (((self.maxSignPeople)[0]) as! String) + "\n岗位为:" + (((self.maxSignPeople)[1]) as! String) + "\n招录人数为:" + (((self.maxSignPeople)[3]) as! String) + "  总报名人数为:" + (((self.maxSignPeople)[4]) as! String) + "  通过审核人数为:" + (((self.maxSignPeople)[5]) as! String)
            resultText = resultText + "\n\n竞争最激烈的岗位为\n"
            for job in self.topJobs {
                resultText = resultText + "组织为:" + (((job as! NSArray)[0]) as! String) + "\n岗位为:" + (((job as! NSArray)[1]) as! String) + "\n招录人数为:" + (((job as! NSArray)[3]) as! String) + "  总报名人数为:" + (((job as! NSArray)[4]) as! String) + "  通过审核人数为:" + (((job as! NSArray)[5]) as! String) + "\n\n"
            }
            
            
            DispatchQueue.main.async {
                resultText = resultText + "\n\n 总体概况为"
                resultText = resultText + "报名总人数为:" + String(self.totalPeoples) + "\n"
                resultText = resultText + "通过审核总人数为:" + String(self.totalPassPeoples) + "\n"
                resultText = resultText + "总的职位为:" + String(self.totalPositions) + "\n"
                resultText = resultText + "总的录取人数为:" + String(self.totalJobs) + "\n\n"
                self.resultBoardLabel.text = resultText
                self.resultBoardLabel.sizeToFit()
            }
        }
    }
    
    
    
    func doRequest() {
        let dataTask = URLSession.shared.dataTask(with: requestUrl) { [weak self] (data, response, error)  in
            guard let strongSelf = self else {
                return
            }
            
            let backToString = String(data: data!, encoding: String.Encoding.utf8)
            strongSelf.reFormString(backToString!)
            
        }

        dataTask.resume()
        
    }
    
    func reFormString(_ serverString: String) {
        //以"<table"开头,以</table>结尾的字符串
        let patternTable = "<table.*</table>"
        let tableString = regexString(serverString, patternTable)
        
        //将网页标签全部替换成空格
        let patternScript = "<script[^>]*?>[\\s\\S]*?<\\/script>" //定义script的正则表达式
        let scriptString = replaceString(tableString, patternScript)
        let patternStyle = "<style[^>]*?>[\\s\\S]*?<\\/style>" //定义style的正则表达式
        let styleString = replaceString(scriptString, patternStyle)
        let patternHtml = "<[^>]+>" //定义HTML标签的正则表达式
        let htmlString = replaceString(styleString, patternHtml)
        converToArray(htmlString)
        semaphore.signal()
        
    }
    
    func regexString(_ regex: String, _ pattern: String) -> String {
        let regexTable = try! NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
        let res = regexTable.matches(in: regex, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, regex.count))
        var resultTable = ""
        for checkingRes in res {
            let lowerBound = String.Index(encodedOffset: checkingRes.range.location)
            let upperBound = String.Index(encodedOffset: checkingRes.range.location + checkingRes.range.length)
            resultTable = resultTable + regex[lowerBound..<upperBound]
        }
        
        return resultTable
    }
    
    func replaceString(_ regex: String, _ pattern: String) -> String {
        let regexTable = try! NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
        let resultString = regexTable.stringByReplacingMatches(in: regex, options: [], range: NSMakeRange(0, regex.count), withTemplate: " ")
        return resultString
    }
    
    
    func converToArray(_ regex: String) {
        var state = 0 //规定遍历的状态,0初始状态或者是遍历的上一个字符为空,1代表上一个遍历的是有用的字符
        var lineIndex = 0 //规定遍历的行数,如果第一行则忽略 7个字段为一行
        var colIndex = 0 //表示遍历到的项数
        var chars = ""
        var spaceNum = 0
        var linePro: NSMutableArray?
        for s in regex {
            if s != " " && state == 0 { //表示要开始遍历了一个单元项目
                if (colIndex == 7) { //表示已经遍历一行了
                    colIndex = 0
                    spaceNum = 0
                    lineIndex = lineIndex + 1
                    if (lineIndex > 0) {
                        if (linePro != nil) {
                            jobs.add(linePro!)
                        }
                        linePro = NSMutableArray.init(capacity: 7)
                    }
                }
                
                chars.append(s)
                colIndex = colIndex + 1
                state = 1
            } else if s == " " && state == 1 && spaceNum >= 2 { //表示已经遍历完一个单元项目
                spaceNum = 0
                if lineIndex > 0 {
                    linePro!.add(chars)
                }
                chars = ""
                state = 0
            } else if state == 1 && s != " " { //表示正在遍历一个单元项目
                chars.append(s)
            }
            
            if s == " " { //如果有项目之间只有一个空格代表这个是连在一起的,大等于2才表示到达下一个项目了
                spaceNum = spaceNum + 1;
            }
        }
    }
    
    func selectJob(_ no: String, _ name: String) -> String {
        for job in jobs {
            if (((job as! NSArray)[0]) as! String).contains(no) &&  (((job as! NSArray)[1]) as! String).contains(name) {
                return "组织为:" + (((job as! NSArray)[0]) as! String) + "\n岗位为:" + (((job as! NSArray)[1]) as! String) + "\n招录人数为:" + (((job as! NSArray)[3]) as! String) + "  总报名人数为:" + (((job as! NSArray)[4]) as! String) + "  通过审核人数为:" + (((job as! NSArray)[5]) as! String)
            }
        }
        return "没有查询到 " + no + " " + name + " 结果"
    }
    
    func top5Jobs() {
        topJobs.add((jobs.firstObject)!)
        var maxSignPeopleNum = 0.0
        var rate1 = 0.0
        var rate2 = 0.0
        for job in jobs {
            
            //统计总的报名人数
            totalPeoples = totalPeoples + Double((((job as! NSArray)[4]) as! String))!
            //统计总的岗位数量
            totalPositions = totalPositions + 1
            //统计总的职位数量
            totalJobs = totalJobs + Double((((job as! NSArray)[3]) as! String))!
            //统计通过审核人数
            totalPassPeoples = totalPassPeoples + Double((((job as! NSArray)[5]) as! String))!
            
            rate1 = Double((((job as! NSArray)[4]) as! String))!/Double((((job as! NSArray)[3]) as! String))!
            rate2 = Double((((topJobs.lastObject as! NSArray)[4]) as! String))!/Double((((topJobs.lastObject as! NSArray)[3]) as! String))!
            
            if Double((((job as! NSArray)[4]) as! String))! > maxSignPeopleNum {
                maxSignPeopleNum = Double((((job as! NSArray)[4]) as! String))!
                maxSignPeople = job as? NSArray
            }
            
            if rate1 > rate2 {
                if topJobs.count > 5 { //对这个职位进行插入操作
                    for index in 0..<topJobs.count {
                        rate2 = Double((((topJobs[index] as! NSArray)[4]) as! String))!/Double((((topJobs[index] as! NSArray)[3]) as! String))!
                        
                        if rate1 > rate2 {
                            topJobs.removeLastObject()
                            topJobs.insert(job, at: index)
                            break
                        }
                    }
                } else {
                    for index in 0..<topJobs.count {
                        rate2 = Double((((topJobs[index] as! NSArray)[4]) as! String))!/Double((((topJobs[index] as! NSArray)[3]) as! String))!
                        
                        if rate1 > rate2 {
                            topJobs.insert(job, at: index)
                            break
                        }
                    }
                }
            }
            
        }
    }

    @IBAction func QueryButtonClicked(_ sender: UIButton) {
        reset()
        doRequest()
        _ = self.semaphore.wait(timeout: .distantFuture)
        let noText = noTextField.text!
        let nameText = jobNameTextField.text!
        var resultText = selectJob(noText, nameText)
        
        top5Jobs()
        resultText = resultText + "\n\n包名人最多的岗位为\n" + "组织为:" + (((maxSignPeople!)[0]) as! String) + "\n岗位为:" + (((maxSignPeople)[1]) as! String) + "\n招录人数为:" + (((maxSignPeople)[3]) as! String) + "  总报名人数为:" + (((maxSignPeople)[4]) as! String) + "  通过审核人数为:" + (((maxSignPeople)[5]) as! String)
        resultText = resultText + "\n\n竞争最激烈的岗位为\n"
        for job in topJobs {
            resultText = resultText + "组织为:" + (((job as! NSArray)[0]) as! String) + "\n岗位为:" + (((job as! NSArray)[1]) as! String) + "\n招录人数为:" + (((job as! NSArray)[3]) as! String) + "  总报名人数为:" + (((job as! NSArray)[4]) as! String) + "  通过审核人数为:" + (((job as! NSArray)[5]) as! String) + "\n"
        }
        
        resultText = resultText + "\n\n 总体概况为"
        resultText = resultText + "报名总人数为:" + String(totalPeoples) + "\n"
        resultText = resultText + "通过审核总人数为:" + String(totalPassPeoples) + "\n"
        resultText = resultText + "总的职位为:" + String(totalPositions) + "\n"
        resultText = resultText + "总的录取人数为:" + String(totalJobs) + "\n\n"
        resultBoardLabel.text = resultText
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        noTextField.resignFirstResponder()
        jobNameTextField.resignFirstResponder()
    }
    
}

