//
//  CHSeries.swift
//  CHKLineChart
//
//  Created by Chance on 16/9/13.
//  Copyright © 2016年 Chance. All rights reserved.
//

import UIKit

/**
 系列对应的key值
 */
public struct CHSeriesKey {
    public static let candle = "Candle"
    public static let timeline = "Timeline"
    public static let volume = "Volume"
    public static let ma = "MA"
    public static let ema = "EMA"
    public static let kdj = "KDJ"
    public static let macd = "MACD"
    public static let boll = "BOLL"
}


/// 线段组
/// 在图表中一个要显示的“线段”都是以一个CHSeries进行封装。
/// 蜡烛图线段：包含一个蜡烛图点线模型（CHCandleModel）
/// 时分线段：包含一个线点线模型（CHLineModel）
/// 交易量线段：包含一个交易量点线模型（CHColumnModel）
/// MA/EMA线段：包含一个线点线模型（CHLineModel）
/// KDJ线段：包含3个线点线模型（CHLineModel），3个点线的数值根据KDJ指标算法计算所得
/// MACD线段：包含2个线点线模型（CHLineModel），1个条形点线模型
open class CHSeries: NSObject {
 
    open var key = ""
    open var title: String = ""
    open var chartModels = [CHChartModel]()          //每个系列包含多个点线模型
    open var hidden: Bool = false
    open var showTitle: Bool = true                                 //是否显示标题文本
    open var baseValueSticky = false                 //是否以固定基值显示最小或最大值，若超过范围
    open var symmetrical = false                     //是否以固定基值为中位数，对称显示最大最小值
    var seriesLayer: CHShapeLayer = CHShapeLayer()      //点线模型的绘图层
    
    public var algorithms: [CHChartAlgorithmProtocol] = [CHChartAlgorithmProtocol]()
    
    /// 清空图表的子图层
    func removeLayerView() {
        _ = self.seriesLayer.sublayers?.map { $0.removeFromSuperlayer() }
        self.seriesLayer.sublayers?.removeAll()
    }
}

// MARK: - 工厂方法
extension CHSeries {
    
    
    /// 返回一个标准的时分价格系列样式
    ///
    /// - Parameters:
    ///   - color: 线段颜色
    ///   - section: 分区
    ///   - showGuide: 是否显示最大最小值
    /// - Returns: 线系列模型
    public class func getTimelinePrice(color: UIColor, section: CHSection, showGuide: Bool = false, ultimateValueStyle: CHUltimateValueStyle = .none, lineWidth: CGFloat = 1) -> CHSeries {
        let series = CHSeries()
        series.key = CHSeriesKey.timeline
        let timeline = CHChartModel.getLine(color, title: NSLocalizedString("Price", comment: ""), key: "\(CHSeriesKey.timeline)_\(section.key)")
        timeline.section = section
        timeline.useTitleColor = false
        timeline.ultimateValueStyle = ultimateValueStyle
        timeline.showMaxVal = showGuide
        timeline.showMinVal = showGuide
        timeline.lineWidth = lineWidth
        series.chartModels = [timeline]
        return series
    }
    
    /**
     返回一个标准的蜡烛柱价格系列样式
     */
    public class func getCandlePrice(upStyle: (color: UIColor, isSolid: Bool),
                                     downStyle: (color: UIColor, isSolid: Bool),
                                     titleColor: UIColor,
                                     section: CHSection,
                                     showGuide: Bool = false,
                                     ultimateValueStyle: CHUltimateValueStyle = .none) -> CHSeries {
        let series = CHSeries()
        series.key = CHSeriesKey.candle
        let candle = CHChartModel.getCandle(upStyle: upStyle, downStyle: downStyle, titleColor: titleColor)
        candle.section = section
        candle.useTitleColor = false
        candle.showMaxVal = showGuide
        candle.showMinVal = showGuide
        candle.ultimateValueStyle = ultimateValueStyle
        series.chartModels = [candle]
        return series
    }
    
    /**
     返回一个标准的交易量系列样式
     */
    public class func getDefaultVolume(upStyle: (color: UIColor, isSolid: Bool),
                                       downStyle: (color: UIColor, isSolid: Bool),
                                       section: CHSection) -> CHSeries {
        let series = CHSeries()
        series.key = CHSeriesKey.volume
        let vol = CHChartModel.getVolume(upStyle: upStyle, downStyle: downStyle)
        vol.section = section
        vol.useTitleColor = false
        series.chartModels = [vol]
        return series
    }
    
    
    /// 获取交易量的MA线
    ///
    public class func getVolumeMA(isEMA: Bool = false, num: [Int], colors: [UIColor], section: CHSection) -> CHSeries {
        let valueKey = CHSeriesKey.volume
        let series = self.getMA(isEMA: isEMA, num: num, colors: colors, valueKey: valueKey, section: section)
        return series
    }
    
    /// 获取交易量的MA线
    ///
    public class func getPriceMA(isEMA: Bool = false, num: [Int], colors: [UIColor], section: CHSection) -> CHSeries {
        let valueKey = CHSeriesKey.timeline
        let series = self.getMA(isEMA: isEMA, num: num, colors: colors, valueKey: valueKey, section: section)
        return series
    }
    
    /**
     返回一个移动平均线系列样式
     */
    public class func getMA(isEMA: Bool = false, num: [Int], colors: [UIColor], valueKey: String, section: CHSection) -> CHSeries {
        var key = ""
        if isEMA {
            key = CHSeriesKey.ema
        } else {
            key = CHSeriesKey.ma
        }
        
        let series = CHSeries()
        series.key = key
        for (i, n) in num.enumerated() {
            
            let ma = CHChartModel.getLine(colors[i], title: "\(key)\(n)", key: "\(key)_\(n)_\(valueKey)")
            ma.section = section
            series.chartModels.append(ma)
        }
        return series
    }
    
    /**
     返回一个KDJ系列样式
     */
    public class func getKDJ(_ kc: UIColor, dc: UIColor, jc: UIColor, section: CHSection) -> CHSeries {
        let series = CHSeries()
        series.key = CHSeriesKey.kdj
        let k = CHChartModel.getLine(kc, title: "K", key: "\(CHSeriesKey.kdj)_K")
        k.section = section
        let d = CHChartModel.getLine(dc, title: "D", key: "\(CHSeriesKey.kdj)_D")
        d.section = section
        let j = CHChartModel.getLine(jc, title: "J", key: "\(CHSeriesKey.kdj)_J")
        j.section = section
        series.chartModels = [k, d, j]
        return series
    }
    
    /**
     返回一个MACD系列样式
     */
    public class func getMACD(_ difc: UIColor,
                              deac: UIColor,
                              barc: UIColor,
                              upStyle: (color: UIColor, isSolid: Bool),
                              downStyle: (color: UIColor, isSolid: Bool),
                              section: CHSection) -> CHSeries {
        let series = CHSeries()
        series.key = CHSeriesKey.macd
        let dif = CHChartModel.getLine(difc, title: "DIF", key: "\(CHSeriesKey.macd)_DIF")
        dif.section = section
        let dea = CHChartModel.getLine(deac, title: "DEA", key: "\(CHSeriesKey.macd)_DEA")
        dea.section = section
        let bar = CHChartModel.getBar(upStyle: upStyle, downStyle: downStyle, titleColor: barc, title: "MACD", key: "\(CHSeriesKey.macd)_BAR")
        bar.section = section
        series.chartModels = [bar, dif, dea]
        return series
    }
}
