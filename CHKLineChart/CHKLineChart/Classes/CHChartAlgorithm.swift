//
//  CHChartAlgorithm.swift
//  CHKLineChart
//
//  Created by Chance on 16/9/14.
//  Copyright © 2016年 Chance. All rights reserved.
//

import UIKit



/// 指标算法协议，用于日后开发者自由扩展编写自己的算法
public protocol CHChartAlgorithmProtocol {
    
    /// 实现该算法的处理
    /// 通过传入一个基本的K线数据模型集合给委托者，完成指标算法计算，
    /// 并把结果记录到CHChartItem的extVal字典中
    /// - Parameter datas: 传入K线数据模型集合
    /// - Returns: 算法的结果记录到CHChartItem的extVal字典中，返回一个处理后的集合
    func handleAlgorithm(_ datas: [CHChartItem]) -> [CHChartItem]
    
}

//MARK: - Equatable
//public func ==(lhs: CHChartAlgorithm, rhs: CHChartAlgorithm) -> Bool {
//    return lhs.hashValue == rhs.hashValue
//}

/**
 常用技术指标算法
 */
public enum CHChartAlgorithm: CHChartAlgorithmProtocol {
    
    case none                                   //无算法
    case timeline                               //时分
    case ma(Int)                                //简单移动平均数
    case ema(Int)                               //指数移动平均数
    case kdj(Int, Int, Int)                     //随机指标
    case macd(Int, Int, Int)                    //指数平滑异同平均线
    case boll(Int, Int)                         //布林线
    
    /**
     获取Key值的名称
     
     - parameter name: 可选的二级key
     
     - returns:
     */
    public func key(_ name: String = "") -> String {
        switch self {
        case .none:
            return ""
        case .timeline:
            return "\(CHSeriesKey.timeline)_\(name)"
        case let .ma(num):
            return "\(CHSeriesKey.ma)_\(num)_\(name)"
        case let .ema(num):
            return "\(CHSeriesKey.ema)_\(num)_\(name)"
        case .kdj(_, _, _):
            return "\(CHSeriesKey.kdj)_\(name)"
        case .macd(_, _, _):
            return "\(CHSeriesKey.macd)_\(name)"
        case .boll(_, _):
            return "\(CHSeriesKey.boll)_\(name)"
        
        }
    }
    
    /**
     处理算法
     
     - parameter datas:
     
     - returns:
     */
    public func handleAlgorithm(_ datas: [CHChartItem]) -> [CHChartItem] {
        switch self {
        case .none:
            return datas
        case .timeline:
            return self.handleTimeline(datas: datas)
        case let .ma(num):
            return self.handleMA(num, datas: datas)
        case let .ema(num):
            return self.handleEMA(num, datas: datas)
        case let .kdj(p1, p2, p3):
            return self.handleKDJ(p1, p2: p2, p3: p3, datas: datas)
        case let .macd(p1, p2, p3):
            return self.handleMACD(p1, p2: p2, p3: p3, datas: datas)
        case let .boll(num, k):
            return self.handleBOLL(num, k: k, datas: datas)
        }
    }
    
    
}

// MARK: - 《时分价格》 处理算法
extension CHChartAlgorithm {
    
    /**
     处理时分价格运算
     使用收盘价为时分价
     - parameter datas: 数据集
     */
    fileprivate func handleTimeline(datas: [CHChartItem]) -> [CHChartItem] {
        for (_, data) in datas.enumerated() {
            data.extVal["\(self.key(CHSeriesKey.timeline))"] = data.closePrice
            data.extVal["\(self.key(CHSeriesKey.volume))"] = data.vol
        }
        return datas
    }
    
}

// MARK: - 《MA简单移动平均数》 处理算法
extension CHChartAlgorithm {
    
    /**
     处理MA运算
     
     - parameter num:   天数
     - parameter datas: 数据集
     */
    fileprivate func handleMA(_ num: Int, datas: [CHChartItem]) -> [CHChartItem] {
        for (index, data) in datas.enumerated() {
            let value = self.getMAValue(num, index: index, datas: datas)
            data.extVal["\(self.key(CHSeriesKey.timeline))"] = value.0
            data.extVal["\(self.key(CHSeriesKey.volume))"] = value.1
        }
        return datas
    }
    
    /**
     计算移动平均数MA
     
     - parameter num:   N
     - parameter index: 数据的位置
     
     - returns: MA数（价格，交易量）
     */
    fileprivate func getMAValue(_ num: Int, index: Int, datas: [CHChartItem]) -> (CGFloat?, CGFloat?) {
        var priceVal: CGFloat = 0
        var volVal: CGFloat = 0
        if index + 1 >= num {       //index + 1 >= N，累计N天内的
            for i in stride(from: index, through: index + 1 - num, by: -1) {
                volVal += datas[i].vol
                priceVal += datas[i].closePrice
            }
            volVal = volVal / CGFloat(num)
            priceVal = priceVal / CGFloat(num)
            return (priceVal, volVal)
        } else {                    //index + 1 < N，累计index + 1天内的
            for i in stride(from: index, through: 0, by: -1) {
                volVal += datas[i].vol
                priceVal += datas[i].closePrice
            }
            volVal = volVal / CGFloat(index + 1)
            priceVal = priceVal / CGFloat(index + 1)
            return (priceVal, volVal)
            // return (nil, nil)
        }
        
    }
    
}

// MARK: - 《EMA指数移动平均数》 处理算法
extension CHChartAlgorithm {
    
    /**
     处理EMA运算
     EMA（N）=2/（N+1）*（C-昨日EMA）+昨日EMA；
     EMA（12）=昨日EMA（12）*11/13+C*2/13；
     - parameter num:   天数
     - parameter datas: 数据集
     */
    fileprivate func handleEMA(_ num: Int, datas: [CHChartItem]) -> [CHChartItem] {
        var prev_ema_price: CGFloat = 0
        var prev_ema_vol: CGFloat = 0
        for (index, data) in datas.enumerated() {
            
            let c = datas[index].closePrice
            let v = datas[index].vol
            
            var ema_price: CGFloat = 0
            var ema_vol: CGFloat = 0
            //EMA（N）=2/（N+1）*（C-昨日EMA）+昨日EMA；
            if index > 0 {
                //EMA（N）=2/（N+1）*（C-昨日EMA）+昨日EMA；
                ema_price = prev_ema_price + (c - prev_ema_price) * 2 / (CGFloat(num) + 1)
                ema_vol = prev_ema_vol + (v - prev_ema_vol) * 2 / (CGFloat(num) + 1)
                
            } else {
                ema_price = c
                ema_vol = v
            }
            
            data.extVal["\(self.key(CHSeriesKey.timeline))"] = ema_price
            data.extVal["\(self.key(CHSeriesKey.volume))"] = ema_vol
            
            prev_ema_price = ema_price
            prev_ema_vol = ema_vol
        }
        return datas
    }
    
}

// MARK: - 《KDJ随机指标》 处理算法
extension CHChartAlgorithm {
    
    /**
     处理KDJ运算
     
     - parameter p1:    指标分析周期
     - parameter p2:    指标分析周期
     - parameter p3:    指标分析周期
     - parameter datas: 未处理的集合
     
     - returns: 处理好的集合
     */
    fileprivate func handleKDJ(_ p1: Int, p2: Int,p3: Int, datas: [CHChartItem]) -> [CHChartItem] {
        var prev_k: CGFloat = 50
        var prev_d: CGFloat = 50
        for (index, data) in datas.enumerated() {
            //计算RSV值
            if let rsv = self.getRSV(p1, index: index, datas: datas) {
                //计算K,D,J值
                let k: CGFloat = (2 * prev_k + rsv) / 3
                let d: CGFloat = (2 * prev_d + k) / 3
                let j: CGFloat = 3 * k - 2 * d
                
                prev_k = k
                prev_d = d
                
                data.extVal["\(self.key("K"))"] = k
                data.extVal["\(self.key("D"))"] = d
                data.extVal["\(self.key("J"))"] = j
            }
        }
        return datas
    }
    
    /**
     RSV计算
     
     - parameter num:   计算天数范围
     - parameter index: 当前的索引位
     
     - returns:
     */
    fileprivate func getRSV(_ num: Int, index: Int, datas: [CHChartItem]) -> CGFloat? {
        var rsv: CGFloat = 0
        let c = datas[index].closePrice
        var h = datas[index].highPrice
        var l = datas[index].lowPrice
        
        let block: (Int) -> Void = {
            (i) -> Void in
            
            let item = datas[i]
            
            if item.highPrice > h {
                h = item.highPrice
            }
            
            if item.lowPrice < l {
                l = item.lowPrice
            }
        }
        
        if index + 1 >= num {    //index + 1 >= N，累计N天内的
            //计算num天数内最低价，最高价
            for i in stride(from: index, through: index + 1 - num, by: -1) {
                block(i)
            }
        } else {                //index + 1 < N，累计index + 1天内的
            //计算index天数内最低价，最高价
            for i in stride(from: index, through: 0, by: -1) {
                block(i)
            }
        }
        
        if h != l {
            rsv = (c - l) / (h - l) * 100
        }
        return rsv
    }
    
}

// MARK: - 《MACD平滑异同移动平均线》 处理算法
extension CHChartAlgorithm {
    
    /**
     处理MACD运算
     EMA（N）=2/（N+1）*（C-昨日EMA）+昨日EMA；
     EMA（12）=昨日EMA（12）*11/13+C*2/13；
     - parameter num:   天数
     - parameter datas: 数据集
     */
    fileprivate func handleMACD(_ p1: Int, p2: Int,p3: Int, datas: [CHChartItem]) -> [CHChartItem] {
        var pre_dea: CGFloat = 0
        for (index, data) in datas.enumerated() {
            //EMA（p1）=2/（p1+1）*（C-昨日EMA）+昨日EMA；
            let (ema1, _) = self.getEMA(p1, index: index, datas: datas)
            //EMA（p2）=2/（p2+1）*（C-昨日EMA）+昨日EMA；
            let (ema2, _) = self.getEMA(p2, index: index, datas: datas)
            
            if ema1 != nil && ema2 != nil {
                //DIF=今日EMA（p1）- 今日EMA（p2）
                let dif = ema1! - ema2!
                //dea（p3）=2/（p3+1）*（dif-昨日dea）+昨日dea；
                let dea = pre_dea + (dif - pre_dea) * 2 / (CGFloat(p3) + 1)
                //BAR=2×(DIF－DEA)
                let bar = 2 * (dif - dea)
                
                data.extVal["\(self.key("DIF"))"] = dif
                data.extVal["\(self.key("DEA"))"] = dea
                data.extVal["\(self.key("BAR"))"] = bar
                
                pre_dea = dea
            }
        }
        return datas
    }
    
    /**
     获取某日的EMA数据
     
     - parameter num:   天数周期
     - parameter index:
     - parameter datas:
     
     - returns: //EMA的成交价和成交量
     */
    fileprivate func getEMA(_ num: Int, index: Int, datas: [CHChartItem]) -> (CGFloat?, CGFloat?) {
        let ema = CHChartAlgorithm.ema(num)
        let data = datas[index]
        let ema_price = data.extVal["\(ema.key(CHSeriesKey.timeline))"]
        let ema_vol = data.extVal["\(ema.key(CHSeriesKey.volume))"]
        return (ema_price, ema_vol)
    }
    
    /**
     获取某日的MA数据
     
     - parameter num:   天数周期
     - parameter index:
     - parameter datas:
     
     - returns: //MA的成交价和成交量
     */
    fileprivate func getMA(_ num: Int, index: Int, datas: [CHChartItem]) -> (CGFloat?, CGFloat?) {
        let ma = CHChartAlgorithm.ma(num)
        let data = datas[index]
        let ma_price = data.extVal["\(ma.key(CHSeriesKey.timeline))"]
        let ma_vol = data.extVal["\(ma.key(CHSeriesKey.volume))"]
        return (ma_price, ma_vol)
    }
}

// MARK: - 《BOLL布林线》 处理算法
extension CHChartAlgorithm {
    
    
    /// 布林线处理方法
    ///
    /// 计算公式
    /// 中轨线=N日的移动平均线
    /// 上轨线=中轨线+两倍的标准差
    /// 下轨线=中轨线－两倍的标准差
    /// 计算过程
    /// （1）计算MA
    /// MA=N日内的收盘价之和÷N
    /// （2）计算标准差MD
    /// MD=平方根（N）日的（C－MA）的两次方之和除以N
    /// （3）计算MB、UP、DN线
    /// MB=（N）日的MA
    /// UP=MB+k×MD
    /// DN=MB－k×MD
    /// （K为参数，可根据股票的特性来做相应的调整，一般默认为2）
    ///
    /// - Parameters:
    ///   - num: 天数
    ///   - k: 参数默认为2
    ///   - datas: 待处理的数据
    /// - Returns: 处理后的数据
    fileprivate func handleBOLL(_ num: Int, k: Int = 2, datas: [CHChartItem]) -> [CHChartItem] {
        var md: CGFloat = 0, mb: CGFloat = 0, up: CGFloat = 0, dn: CGFloat = 0
        for (index, data) in datas.enumerated() {
            //计算标准差
            md = self.handleBOLLSTD(num, index: index, datas: datas)
            mb = self.getMA(num, index: index, datas: datas).0 ?? 0
            up = mb + CGFloat(k) * md
            dn = mb - CGFloat(k) * md
            
            data.extVal["\(self.key("BOLL"))"] = mb
            data.extVal["\(self.key("UP"))"] = up
            data.extVal["\(self.key("LB"))"] = dn
        }
        
        return datas
    }
    
    
    /// 计算布林线中的MA平方差
    ///
    /// - Parameters:
    ///   - num: 累计的天数
    ///   - index: 当天日期
    ///   - datas: 数据集合
    /// - Returns: 结果
    fileprivate func handleBOLLSTD(_ num: Int, index: Int, datas: [CHChartItem]) -> CGFloat {
        var dx: CGFloat = 0, md: CGFloat = 0
        let ma = self.getMA(num, index: index, datas: datas).0 ?? 0
        if index + 1 >= num {       //index + 1 >= N，计算N日的平方差
            for i in stride(from: index, through: index + 1 - num, by: -1) {
                dx += pow(datas[i].closePrice - ma, 2)
            }
            md = dx / CGFloat(num)
        } else {                    //index + 1 < N，计算index + 1日的平方差
            for i in stride(from: index, through: 0, by: -1) {
                dx += pow(datas[i].closePrice - ma, 2)
            }
            md = dx / CGFloat(index + 1)
        }
        return md
    }
}
