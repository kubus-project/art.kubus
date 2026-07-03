import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var mapBackdropHost: KubusMapNativeBackdropHostPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      mapBackdropHost = KubusMapNativeBackdropHostPlugin(
        messenger: controller.binaryMessenger,
        flutterViewProvider: { [weak controller] in controller?.view }
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Native side of the map-glass backdrop host (`art.kubus/map_native_backdrop`).
///
/// Flutter registers screen-space glass regions that sit over the MapLibre
/// platform view. This host inserts real blur views INSIDE the map view —
/// above the map rendering, below Flutter's overlay layer — the same sandwich
/// the web DOM/CSS host builds. Materials: Apple's Liquid Glass
/// (`UIGlassEffect`, iOS 26+) when available at runtime, otherwise a
/// `UIVisualEffectView` blur material.
///
/// Every operation is best-effort: if the map view cannot be found (route
/// transitions, map not mounted yet) the regions are cleared and the next sync
/// retries. The Dart side treats any channel error as "unsupported" and falls
/// back to its tint sheen, so this host can never make things worse.
final class KubusMapNativeBackdropHostPlugin: NSObject {
  private let flutterViewProvider: () -> UIView?
  private var hostView: UIView?
  private var regionViews: [String: UIVisualEffectView] = [:]

  init(
    messenger: FlutterBinaryMessenger,
    flutterViewProvider: @escaping () -> UIView?
  ) {
    self.flutterViewProvider = flutterViewProvider
    super.init()

    let channel = FlutterMethodChannel(
      name: "art.kubus/map_native_backdrop",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "isSupported":
        result(true)
      case "syncRegions":
        self.syncRegions(arguments: call.arguments)
        result(nil)
      case "clearRegions":
        self.clearRegions()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Region sync

  private func syncRegions(arguments: Any?) {
    guard
      let args = arguments as? [String: Any],
      let regions = args["regions"] as? [[String: Any]],
      !regions.isEmpty,
      let flutterView = flutterViewProvider(),
      let mapView = findMapView(in: flutterView)
    else {
      clearRegions()
      return
    }

    let host = ensureHost(on: mapView)
    var activeIds = Set<String>()

    for region in regions {
      guard
        let id = region["id"] as? String,
        let left = doubleValue(region["left"]),
        let top = doubleValue(region["top"]),
        let width = doubleValue(region["width"]),
        let height = doubleValue(region["height"]),
        width > 0, height > 0
      else { continue }

      // Region rects arrive in Flutter logical pixels (== points) in the
      // Flutter root view's coordinate space; convert into the map view and
      // clamp so blur never paints outside the map.
      let globalRect = CGRect(x: left, y: top, width: width, height: height)
      let localRect = flutterView
        .convert(globalRect, to: mapView)
        .intersection(mapView.bounds)
      if localRect.isNull || localRect.isEmpty { continue }

      activeIds.insert(id)
      let view = regionViews[id] ?? makeRegionView()
      regionViews[id] = view
      if view.superview !== host {
        host.addSubview(view)
      }
      view.frame = localRect
      let radius = doubleValue(region["cornerRadius"]) ?? 0
      view.layer.cornerRadius = CGFloat(max(0, radius))
    }

    for (id, view) in regionViews where !activeIds.contains(id) {
      view.removeFromSuperview()
      regionViews.removeValue(forKey: id)
    }
  }

  private func clearRegions() {
    for view in regionViews.values {
      view.removeFromSuperview()
    }
    regionViews.removeAll()
    hostView?.removeFromSuperview()
    hostView = nil
  }

  // MARK: - Views

  private func ensureHost(on mapView: UIView) -> UIView {
    if let existing = hostView, existing.superview === mapView {
      existing.frame = mapView.bounds
      mapView.bringSubviewToFront(existing)
      return existing
    }
    hostView?.removeFromSuperview()
    for view in regionViews.values {
      view.removeFromSuperview()
    }

    let host = UIView(frame: mapView.bounds)
    host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.isUserInteractionEnabled = false
    host.backgroundColor = .clear
    mapView.addSubview(host)
    hostView = host
    return host
  }

  private func makeRegionView() -> UIVisualEffectView {
    let view = UIVisualEffectView(effect: resolveGlassEffect())
    view.isUserInteractionEnabled = false
    view.clipsToBounds = true
    if #available(iOS 13.0, *) {
      view.layer.cornerCurve = .continuous
    }
    return view
  }

  /// Prefers Apple's Liquid Glass (`UIGlassEffect`, iOS 26+) resolved via the
  /// runtime so this file compiles against older SDKs; falls back to a thin
  /// blur material.
  private func resolveGlassEffect() -> UIVisualEffect {
    if let glassClass = NSClassFromString("UIGlassEffect") as? NSObject.Type,
       let glass = glassClass.init() as? UIVisualEffect {
      return glass
    }
    if #available(iOS 13.0, *) {
      return UIBlurEffect(style: .systemUltraThinMaterial)
    }
    return UIBlurEffect(style: .regular)
  }

  // MARK: - Helpers

  private func doubleValue(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    return value as? Double
  }

  /// Breadth-first search for the MapLibre map view hosted by the platform
  /// view (`MLNMapView` on current MapLibre Native, `MGLMapView` on older
  /// builds).
  private func findMapView(in root: UIView) -> UIView? {
    var queue: [UIView] = [root]
    var visited = 0
    while !queue.isEmpty && visited < 600 {
      let view = queue.removeFirst()
      visited += 1
      let className = String(describing: type(of: view))
      if className.contains("MLNMapView") || className.contains("MGLMapView") {
        return view
      }
      queue.append(contentsOf: view.subviews)
    }
    return nil
  }
}
