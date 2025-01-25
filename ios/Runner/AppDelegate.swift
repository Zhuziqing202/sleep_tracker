import Flutter
import UIKit
import HealthKit
import UserNotifications
import BackgroundTasks
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private var healthStore: HKHealthStore?
  private var sleepObserverQuery: HKObserverQuery?
  private var stepsObserverQuery: HKObserverQuery?
  private var channel: FlutterMethodChannel?
  private var locationManager: CLLocationManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    channel = FlutterMethodChannel(name: "com.example.sleep_tracker/health",
                                              binaryMessenger: controller.binaryMessenger)
    
    channel?.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "getSleepData":
        self?.getSleepData(result: result)
      case "startMonitoring":
        self?.startMonitoringSleep(result: result)
      case "stopMonitoring":
        self?.stopMonitoringSleep(result: result)
      case "startStepsMonitoring":
        self?.startStepsMonitoring(result: result)
      case "stopStepsMonitoring":
        self?.stopStepsMonitoring(result: result)
      case "getPreSleepParameters":
        self?.fetchPreSleepParameters(completion: result)
      case "getLast30DaysSleepData":
        self?.getLast30DaysSleepData(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // 初始化 HealthStore
    if HKHealthStore.isHealthDataAvailable() {
      healthStore = HKHealthStore()
    }
    
    // 请求通知权限
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge, .provisional, .criticalAlert]
    ) { granted, error in
      print("通知权限状态: \(granted)")
      if granted {
        // 设置通知中心代理
        UNUserNotificationCenter.current().delegate = self
      }
    }
    
    // 注册后台任务
    UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    
    // 请求后台刷新权限
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.sleep_tracker.refresh",
      using: nil
    ) { task in
      self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }
    
    // 修改定位管理器的初始化方式
    locationManager = CLLocationManager()
    if let manager = locationManager {
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = false
        manager.startMonitoringSignificantLocationChanges()
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startMonitoringSleep(result: @escaping FlutterResult) {
    guard let healthStore = healthStore else {
        result(FlutterError(code: "HEALTH_DATA_NOT_AVAILABLE",
                           message: "HealthKit在此设备上不可用",
                           details: nil))
        return
    }
    
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    let typesToRead: Set<HKObjectType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!
    ]
    
    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
        if !success {
            result(FlutterError(code: "PERMISSION_DENIED",
                               message: "未获得健康数据访问权限",
                               details: error?.localizedDescription))
            return
        }
        
        if let self = self {
            self.setupSleepMonitoring(healthStore: healthStore)
            result(nil)
        }
    }
  }
  
  private func setupSleepMonitoring(healthStore: HKHealthStore) {
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // 启用后台更新，使用立即更新策略
    healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { (success, error) in
        if success {
            print("睡眠数据后台更新已启用")
            // 立即执行一次查询
            self.fetchLatestSleepData { _ in }
        } else if let error = error {
            print("睡眠数据后台更新启用失败: \(error.localizedDescription)")
        }
    }
    
    // 创建观察者查询
    sleepObserverQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] (query, completionHandler, error) in
        self?.fetchLatestSleepData { sleepInfo in
            DispatchQueue.main.async {
                self?.channel?.invokeMethod("onSleepDataChanged", arguments: sleepInfo)
                // 使用高优先级通知
                self?.showNotification(
                    title: "睡眠状态更新",
                    body: sleepInfo,
                    highPriority: true
                )
            }
        }
        completionHandler()
    }
    
    if let query = sleepObserverQuery {
        healthStore.execute(query)
    }
  }
  
  private func setupStepsMonitoring(healthStore: HKHealthStore) {
    let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    var lastStepCount: Int = 0
    
    // 使用最高频率进行后台更新
    healthStore.enableBackgroundDelivery(for: stepsType, frequency: .immediate) { (success, error) in
        if success {
            print("步数后台更新已启用（最高频率模式）")
            self.fetchTodaySteps { _, _ in }
        } else if let error = error {
            print("步数后台更新启用失败: \(error.localizedDescription)")
        }
    }
    
    // 创建多个高频定时器
    DispatchQueue.global(qos: .userInitiated).async {  // 使用更高优先级的队列
        // 15秒更新一次
        let ultraShortTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.fetchTodaySteps { _, _ in }
        }
        
        // 30秒更新一次（作为备份）
        let shortTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchTodaySteps { _, _ in }
        }
        
        // 确保定时器在后台运行
        RunLoop.current.add(ultraShortTimer, forMode: .common)
        RunLoop.current.add(shortTimer, forMode: .common)
        RunLoop.current.run()
    }
    
    // 创建观察者查询
    stepsObserverQuery = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] (query, completionHandler, error) in
        self?.fetchTodaySteps { stepsInfo, currentSteps in
            if currentSteps != lastStepCount {
                DispatchQueue.main.async {
                    self?.channel?.invokeMethod("onStepsDataChanged", arguments: stepsInfo)
                    self?.showNotification(
                        title: "步数更新",
                        body: "您的\(stepsInfo)",
                        highPriority: true
                    )
                    lastStepCount = currentSteps
                }
            }
        }
        completionHandler()
    }
    
    if let query = stepsObserverQuery {
        healthStore.execute(query)
        scheduleAppRefresh()
    }
  }
  
  private func fetchTodaySteps(completion: @escaping (String, Int) -> Void) {
    guard let healthStore = healthStore else { return }
    
    let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
    
    let query = HKStatisticsQuery(quantityType: stepsType,
                                 quantitySamplePredicate: predicate,
                                 options: .cumulativeSum) { _, result, error in
      guard let result = result,
            let sum = result.sumQuantity() else {
        completion("今日步数：0 步", 0)
        return
      }
      
      let steps = Int(sum.doubleValue(for: HKUnit.count()))
      let info = "今日步数：\(steps) 步"
      completion(info, steps)
    }
    
    healthStore.execute(query)
  }
  
  private func stopMonitoringSleep(result: @escaping FlutterResult) {
    if let sleepQuery = sleepObserverQuery {
      healthStore?.stop(sleepQuery)
      sleepObserverQuery = nil
    }
    result(nil)
  }
  
  private func fetchLatestSleepData(completion: @escaping (String) -> Void) {
    guard let healthStore = healthStore else { return }
    
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // 获取最近6小时的数据
    let now = Date()
    let sixHoursAgo = Calendar.current.date(byAdding: .hour, value: -6, to: now)!
    let predicate = HKQuery.predicateForSamples(
        withStart: sixHoursAgo,
        end: now,
        options: .strictEndDate
    )
    
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
        sampleType: sleepType,
        predicate: predicate,
        limit: 1,  // 只获取最近的一条记录
        sortDescriptors: [sortDescriptor]
    ) { (_, samples, error) in
        guard let latestSample = samples?.first as? HKCategorySample else {
            completion("当前未在睡眠，且近6小时内无睡眠记录")
            return
        }
        
        let stage = self.getSleepStageDescription(value: latestSample.value)
        let endTime = latestSample.endDate
        
        if endTime > now {
            // 当前正在睡眠中
            completion("当前状态：\(stage)")
        } else {
            // 最近的睡眠已结束
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let endTimeStr = formatter.string(from: endTime)
            completion("当前未在睡眠\n最近睡眠状态：\(stage)\n结束时间：\(endTimeStr)")
        }
    }
    
    healthStore.execute(query)
  }
  
  private func showNotification(title: String, body: String, highPriority: Bool = false) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    if highPriority {
        // 设置为高优先级通知
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive  // 直接设置属性
            
            // 如果需要关键通知，直接设置为 critical
            // content.interruptionLevel = .critical    // 需要特殊权限
        }
        content.threadIdentifier = "sleep_tracker_notifications"
    }
    
    // 确保通知能在锁屏时显示
    content.categoryIdentifier = highPriority ? "CRITICAL_UPDATE" : "NORMAL_UPDATE"
    
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("发送通知失败: \(error.localizedDescription)")
        }
    }
  }
  
  private func getSleepData(result: @escaping FlutterResult) {
    guard let healthStore = self.healthStore else {
        result(FlutterError(code: "HEALTH_DATA_NOT_AVAILABLE",
                           message: "HealthKit在此设备上不可用",
                           details: nil))
        return
    }
    
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // 获取时间范围：昨天18:00到今天12:00
    let calendar = Calendar.current
    let now = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
    let startDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
    let endDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
    
    let predicate = HKQuery.predicateForSamples(
        withStart: startDate,
        end: endDate,
        options: .strictStartDate
    )
    
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    
    let query = HKSampleQuery(
        sampleType: sleepType,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sortDescriptor]
    ) { (_, samples, error) in
        if let error = error {
            result(FlutterError(code: "QUERY_ERROR",
                              message: "查询睡眠数据失败",
                              details: error.localizedDescription))
            return
        }
        
        guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
            result("未找到睡眠数据")
            return
        }
        
        // 处理睡眠数据
        var report = "昨晚睡眠记录：\n"
        report += "记录时间范围：\(self.formatDate(startDate)) - \(self.formatDate(endDate))\n\n"
        
        var totalSleepDuration: TimeInterval = 0
        
        for sample in samples {
            let stage = self.getSleepStageDescription(value: sample.value)
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            
            report += "阶段：\(stage)\n"
            report += "开始：\(self.formatDate(sample.startDate))\n"
            report += "结束：\(self.formatDate(sample.endDate))\n"
            report += "持续时间：\(hours)小时\(minutes)分钟\n"
            report += "------------------------\n"
            
            // 只计算睡眠时间（排除清醒和在床上状态）
            if sample.value != HKCategoryValueSleepAnalysis.awake.rawValue &&
               sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue {
                totalSleepDuration += duration
            }
        }
        
        let totalHours = Int(totalSleepDuration / 3600)
        let totalMinutes = Int((totalSleepDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        report += "\n总睡眠时间：\(totalHours)小时\(totalMinutes)分钟"
        
        result(report)
    }
    
    healthStore.execute(query)
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
  }
  
  private func getSleepStageDescription(value: Int) -> String {
    switch value {
    case HKCategoryValueSleepAnalysis.inBed.rawValue:
        return "在床上"
    case HKCategoryValueSleepAnalysis.awake.rawValue:
        return "清醒"
    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
        return "浅睡/中度睡眠"
    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
        return "深度睡眠"
    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
        return "REM睡眠"
    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
        return "睡眠（未指定阶段）"
    default:
        return "未知状态"
    }
  }
  
  private func startStepsMonitoring(result: @escaping FlutterResult) {
    guard let healthStore = healthStore else {
      result(FlutterError(code: "HEALTH_DATA_NOT_AVAILABLE",
                         message: "HealthKit在此设备上不可用",
                         details: nil))
      return
    }
    
    let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    
    healthStore.requestAuthorization(toShare: nil, read: [stepsType]) { [weak self] (success, error) in
      if !success {
        result(FlutterError(code: "PERMISSION_DENIED",
                           message: "未获得健康数据访问权限",
                           details: error?.localizedDescription))
        return
      }
      
      self?.setupStepsMonitoring(healthStore: healthStore)
      result(nil)
    }
  }
  
  private func stopStepsMonitoring(result: @escaping FlutterResult) {
    if let stepsQuery = stepsObserverQuery {
      healthStore?.stop(stepsQuery)
      stepsObserverQuery = nil
    }
    result(nil)
  }
  
  // 处理后台刷新任务
  private func handleAppRefresh(task: BGAppRefreshTask) {
    // 安排下一次后台任务
    scheduleAppRefresh()
    
    // 确保任务在超时前完成
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }
    
    // 更新健康数据
    if let healthStore = self.healthStore {
      // 更新步数
      self.fetchTodaySteps { stepsInfo, currentSteps in
        self.channel?.invokeMethod("onStepsDataChanged", arguments: stepsInfo)
      }
      
      // 更新睡眠数据
      self.fetchLatestSleepData { sleepInfo in
        self.channel?.invokeMethod("onSleepDataChanged", arguments: sleepInfo)
      }
    }
    
    // 标记任务完成
    task.setTaskCompleted(success: true)
  }
  
  // 安排后台刷新任务
  private func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.sleep_tracker.refresh")
    // 设置为最短间隔（30秒）
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
    
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("无法安排后台任务: \(error)")
    }
  }
  
  // 处理定位更新
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // 保持应用活跃
    if let healthStore = self.healthStore {
      self.fetchTodaySteps { _, _ in }
    }
  }
  
  // 添加应用进入后台的处理
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    
    // 请求最长的后台处理时间
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    backgroundTask = application.beginBackgroundTask {
        application.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // 立即开始数据获取
    if let healthStore = self.healthStore {
        self.fetchTodaySteps { _, _ in }
    }
    
    // 启用高频率位置更新
    locationManager?.allowsBackgroundLocationUpdates = true
    locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    locationManager?.distanceFilter = 1.0  // 1米更新一次
    locationManager?.startUpdatingLocation()
    
    // 额外的定时器来保持活跃
    DispatchQueue.global(qos: .userInitiated).async {
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.fetchTodaySteps { _, _ in }
        }
    }
  }
  
  // 添加应用将要进入前台的处理
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    
    // 停止位置更新以节省电量
    locationManager?.stopUpdatingLocation()
    
    // 立即刷新数据
    if let healthStore = self.healthStore {
        self.fetchTodaySteps { _, _ in }
    }
  }
  
  private func fetchPreSleepParameters(completion: @escaping (String) -> Void) {
    guard let healthStore = healthStore else { return }
    
    // 首先获取昨晚第一个睡眠阶段
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    let calendar = Calendar.current
    let now = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
    let startDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
    let endDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
    
    let sleepPredicate = HKQuery.predicateForSamples(
        withStart: startDate,
        end: endDate,
        options: .strictStartDate
    )
    
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    
    // 创建一个组来同步多个异步查询
    let group = DispatchGroup()
    var report = "睡前1小时生理指标报告：\n"
    
    // 首先获取第一个睡眠阶段的开始时间
    let sleepQuery = HKSampleQuery(
        sampleType: sleepType,
        predicate: sleepPredicate,
        limit: 1,
        sortDescriptors: [sortDescriptor]
    ) { (_, samples, error) in
        guard let firstSleep = samples?.first as? HKCategorySample else {
            completion("未找到睡眠记录")
            return
        }
        
        let sleepStart = firstSleep.startDate
        let periodStart = calendar.date(byAdding: .hour, value: -1, to: sleepStart)!
        
        // 创建时间范围谓词
        let periodPredicate = HKQuery.predicateForSamples(
            withStart: periodStart,
            end: sleepStart,
            options: .strictStartDate
        )
        
        // 获取心率数据（每15分钟一个数据点）
        group.enter()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let heartRateQuery = HKSampleQuery(
            sampleType: heartRateType,
            predicate: periodPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            var heartRates: [String] = []
            if let samples = samples as? [HKQuantitySample] {
                for sample in samples {
                    let value = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                    let time = self.formatTime(sample.startDate)
                    heartRates.append("\(time): \(value)次/分钟")
                }
                if !heartRates.isEmpty {
                    report += "\n心率变化：\n"
                    report += heartRates.joined(separator: "\n")
                }
            }
            group.leave()
        }
        
        // 获取血氧饱和度数据
        group.enter()
        let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let oxygenQuery = HKSampleQuery(
            sampleType: oxygenType,
            predicate: periodPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            var oxygenLevels: [String] = []
            if let samples = samples as? [HKQuantitySample] {
                for sample in samples {
                    let value = Int(sample.quantity.doubleValue(for: HKUnit.percent()) * 100)
                    let time = self.formatTime(sample.startDate)
                    oxygenLevels.append("\(time): \(value)%")
                }
                if !oxygenLevels.isEmpty {
                    report += "\n\n血氧饱和度变化：\n"
                    report += oxygenLevels.joined(separator: "\n")
                }
            }
            group.leave()
        }
        
        // 获取步数数据
        group.enter()
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepsQuery = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: periodPredicate,
            options: .cumulativeSum
        ) { _, statistics, _ in
            if let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) {
                report += "\n\n这一小时内的步数：\(Int(sum))步\n"
            }
            group.leave()
        }
        
        // 获取能量消耗
        group.enter()
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let energyQuery = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: periodPredicate,
            options: .cumulativeSum
        ) { _, statistics, _ in
            if let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) {
                report += "\n活动能量消耗：\(Int(sum))千卡\n"
            }
            group.leave()
        }
        
        // 获取环境音量数据
        group.enter()
        if let environmentalAudioType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) {
            let audioQuery = HKSampleQuery(
                sampleType: environmentalAudioType,
                predicate: periodPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                var audioLevels: [String] = []
                if let samples = samples as? [HKQuantitySample] {
                    for sample in samples {
                        let value = Int(sample.quantity.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel()))
                        let time = self.formatTime(sample.startDate)
                        audioLevels.append("\(time): \(value)dBA")
                    }
                    if !audioLevels.isEmpty {
                        report += "\n\n环境音量变化：\n"
                        report += audioLevels.joined(separator: "\n")
                    }
                }
                group.leave()
            }
            healthStore.execute(audioQuery)
        } else {
            group.leave()
        }
        
        // 执行所有查询
        healthStore.execute(heartRateQuery)
        healthStore.execute(oxygenQuery)
        healthStore.execute(stepsQuery)
        healthStore.execute(energyQuery)
        
        // 当所有查询完成时
        group.notify(queue: .main) {
            if report == "睡前1小时生理指标报告：\n" {
                completion("未找到相关生理指标数据")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let header = "睡眠开始时间：\(formatter.string(from: sleepStart))\n" +
                            "统计时段：\(formatter.string(from: periodStart)) - \(formatter.string(from: sleepStart))"
                
                // 使用 ### 作为分隔符，确保数据不会混淆
                let sections = report.components(separatedBy: "\n\n")
                    .filter { !$0.isEmpty }
                    .joined(separator: "###")
                
                completion("\(header)###\(sections)")
            }
        }
    }
    
    healthStore.execute(sleepQuery)
  }
  
  // 添加辅助方法用于格式化时间
  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }
  
  private func getLast30DaysSleepData(result: @escaping FlutterResult) {
    guard let healthStore = healthStore else {
        result(FlutterError(code: "HEALTH_DATA_NOT_AVAILABLE",
                           message: "HealthKit不可用",
                           details: nil))
        return
    }
    
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    let calendar = Calendar.current
    let now = Date()
    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
    
    var sleepData: [[String: Any]] = []
    let group = DispatchGroup()
    
    for dayOffset in 0..<30 {
        group.enter()
        let currentDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
        let startOfDay = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: currentDate)!)!
        let endOfDay = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: currentDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            defer { group.leave() }
            
            guard let samples = samples as? [HKCategorySample] else { return }
            
            var totalSleep = TimeInterval(0)
            var deepSleep = TimeInterval(0)
            var lightSleep = TimeInterval(0)
            var remSleep = TimeInterval(0)
            var firstBedTime: Date?
            var lastWakeTime: Date?
            
            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                if firstBedTime == nil {
                    firstBedTime = sample.startDate
                }
                lastWakeTime = sample.endDate
                
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepSleep += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    lightSleep += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remSleep += duration
                default:
                    break
                }
            }
            
            // 在循环结束后计算总睡眠时长
            totalSleep = deepSleep + lightSleep + remSleep
            
            if totalSleep > 0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                let dayData: [String: Any] = [
                    "date": formatter.string(from: currentDate),
                    "totalDuration": Int(totalSleep),
                    "deepSleep": Int(deepSleep),
                    "lightSleep": Int(lightSleep),
                    "remSleep": Int(remSleep),
                    "bedTime": formatter.string(from: firstBedTime ?? currentDate),
                    "wakeTime": formatter.string(from: lastWakeTime ?? currentDate)
                ]
                sleepData.append(dayData)
            }
        }
        
        healthStore.execute(query)
    }
    
    group.notify(queue: .main) {
        result(sleepData)
    }
  }
}

// 修改通知代理扩展
extension AppDelegate {
  // 在前台也显示通知
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // 设置通知在前台显示时的选项
    completionHandler([.banner, .sound, .badge])
  }
  
  // 处理通知响应
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
