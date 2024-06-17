import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import ItemListUI
import AccountContext
import PresentationDataUtils
import ListSectionComponent
import TelegramStringFormatting
import UndoUI

private let amountTag = GenericComponentViewTag()

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: StarsWithdrawScreen.Mode
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let closeButton = Child(Button.self)
        let title = Child(Text.self)
        let urlSection = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
        let balanceTitle = Child(MultilineTextComponent.self)
        let balanceValue = Child(MultilineTextComponent.self)
        let balanceIcon = Child(BundleIconComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme.withModalBlocksBackground()
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 18.0)
                        
            let background = background.update(
                component: RoundedRectangle(color: theme.list.blocksBackgroundColor, cornerRadius: 8.0),
                availableSize: CGSize(width: context.availableSize.width, height: 1000.0),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let constrainedTitleWidth = context.availableSize.width - 16.0 * 2.0
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - closeButton.size.width, y: 28.0))
            )
            
            let titleString: String
            let amountTitle: String
            let amountPlaceholder: String
            
            let minAmount: Int64?
            let maxAmount: Int64?
            
            switch component.mode {
            case let .withdraw(status):
                titleString = environment.strings.Stars_Withdraw_Title
                amountTitle = environment.strings.Stars_Withdraw_AmountTitle
                amountPlaceholder = environment.strings.Stars_Withdraw_AmountPlaceholder
                
                let configuration = StarsWithdrawConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                minAmount = configuration.minWithdrawAmount
                maxAmount = status.balances.availableBalance
            case .paidMedia:
                titleString = environment.strings.Stars_PaidContent_Title
                amountTitle = environment.strings.Stars_PaidContent_AmountTitle
                amountPlaceholder = environment.strings.Stars_PaidContent_AmountPlaceholder
               
                minAmount = 1
                maxAmount = nil
            }
            
            let title = title.update(
                component: Text(text: titleString, font: Font.bold(17.0), color: theme.list.itemPrimaryTextColor),
                availableSize: CGSize(width: constrainedTitleWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += 40.0
            
            if case let .withdraw(starsState) = component.mode {
                let balanceTitle = balanceTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Stars_Transfer_Balance,
                            font: Font.regular(14.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                let balanceValue = balanceValue.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: presentationStringsFormattedNumber(Int32(starsState.balances.availableBalance), environment.dateTimeFormat.groupingSeparator),
                            font: Font.semibold(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                let balanceIcon = balanceIcon.update(
                    component: BundleIconComponent(name: "Premium/Stars/StarSmall", tintColor: nil),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                
                let topBalanceOriginY = 11.0
                context.add(balanceTitle
                    .position(CGPoint(x: 16.0 + environment.safeInsets.left + balanceTitle.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height / 2.0))
                )
                context.add(balanceIcon
                    .position(CGPoint(x: 16.0 + environment.safeInsets.left + balanceIcon.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0 + 1.0 + UIScreenPixel))
                )
                context.add(balanceValue
                    .position(CGPoint(x: 16.0 + environment.safeInsets.left + balanceIcon.size.width + 3.0 + balanceValue.size.width / 2.0, y: topBalanceOriginY + balanceTitle.size.height + balanceValue.size.height / 2.0 + 2.0 - UIScreenPixel))
                )
            }
            
            let amountFooter: AnyComponent<Empty>?
            if case .paidMedia = component.mode {
                let amountFont = Font.regular(13.0)
                let amountTextColor = theme.list.freeTextColor
                let amountMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: amountFont, textColor: amountTextColor), bold: MarkdownAttributeSet(font: amountFont, textColor: amountTextColor), link: MarkdownAttributeSet(font: amountFont, textColor: theme.list.itemAccentColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                let amountInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.Stars_PaidContent_AmountInfo, attributes: amountMarkdownAttributes, textAlignment: .natural))
                if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                    state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
                }
                if let range = amountInfoString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                    amountInfoString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: amountInfoString.string))
                }
                amountFooter = AnyComponent(MultilineTextComponent(
                    text: .plain(amountInfoString),
                    maximumNumberOfLines: 0
                ))
            } else {
                amountFooter = nil
            }
                         
            let urlSection = urlSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: amountTitle.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: amountFooter,
                    items: [
                        AnyComponentWithIdentity(
                            id: "amount",
                            component: AnyComponent(
                                AmountFieldComponent(
                                    textColor: theme.list.itemPrimaryTextColor,
                                    placeholderColor: theme.list.itemPlaceholderTextColor,
                                    value: state.amount,
                                    minValue: minAmount,
                                    maxValue: maxAmount,
                                    placeholderText: amountPlaceholder,
                                    amountUpdated: { [weak state] amount in
                                        state?.amount = amount
                                        state?.updated()
                                    },
                                    tag: amountTag
                                )
                            )
                        )
                    ]
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(urlSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + urlSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            contentSize.height += urlSection.size.height
            contentSize.height += 32.0
            
            let buttonString: String
            if case .paidMedia = component.mode {
                buttonString = environment.strings.Stars_PaidContent_Create
            } else if let amount = state.amount {
                buttonString = "\(environment.strings.Stars_Withdraw_Withdraw)   #  \(amount)"
            } else {
                buttonString = environment.strings.Stars_Withdraw_Withdraw
            }
            
            if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white)!, theme)
            }
            
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let controller = environment.controller
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak state] in
                        if let controller = controller() as? StarsWithdrawScreen, let amount = state?.amount {
                            if let minAmount, amount < minAmount {
                                controller.presentMinAmountTooltip(minAmount)
                            } else {
                                controller.completion(amount)
                                controller.dismissAnimated()
                            }
                        }
                    }
                ),
                availableSize: CGSize(width: 361.0, height: 50),
                transition: .immediate
            )
            context.add(button
                .clipsToBounds(true)
                .cornerRadius(10.0)
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
            contentSize.height += 15.0
            
            contentSize.height += max(environment.inputHeight, environment.safeInsets.bottom)

            return contentSize
        }
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        fileprivate var amount: Int64?
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        init(
            context: AccountContext,
            amount: Int64?
        ) {
            self.context = context
            self.amount = amount
            
            super.init()
        }
    }
    
    func makeState() -> State {
        var amount: Int64?
        if case let .withdraw(stats) = mode {
            amount = stats.balances.availableBalance
        }
        return State(context: self.context, amount: amount)
    }
}

private final class StarsWithdrawSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let mode: StarsWithdrawScreen.Mode
    
    init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode
    ) {
        self.context = context
        self.mode = mode
    }
    
    static func ==(lhs: StarsWithdrawSheetComponent, rhs: StarsWithdrawSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
        
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        mode: context.component.mode,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .blur(.light),
                    followContentSizeChanges: false,
                    clipsContent: true,
                    isScrollEnabled: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class StarsWithdrawScreen: ViewControllerComponentContainer {
    public enum Mode: Equatable {
        case withdraw(StarsRevenueStats)
        case paidMedia
    }
    
    private let context: AccountContext
    fileprivate let completion: (Int64) -> Void
        
    public init(
        context: AccountContext,
        mode: StarsWithdrawScreen.Mode,
        completion: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        super.init(
            context: context,
            component: StarsWithdrawSheetComponent(
                context: context,
                mode: mode
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let view = self.node.hostView.findTaggedView(tag: amountTag) as? AmountFieldComponent.View {
            Queue.mainQueue().after(0.01) {
                view.activateInput()
                view.selectAll()
            }
        }
    }
    
    func presentMinAmountTooltip(_ minAmount: Int64) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let resultController = UndoOverlayController(
            presentationData: presentationData,
            content: .image(
                image: UIImage(bundleImageName: "Premium/Stars/StarLarge")!,
                title: nil,
                text: presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum(presentationData.strings.Stars_Withdraw_Withdraw_ErrorMinimum_Stars(Int32(minAmount))).string,
                round: false,
                undoText: nil
            ),
            elevatedLayout: false,
            position: .top,
            action: { _ in return true})
        self.present(resultController, in: .window(.root))
        
        if let view = self.node.hostView.findTaggedView(tag: amountTag) as? AmountFieldComponent.View {
            view.animateError()
        }
    }
        
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class AmountFieldComponent: Component {
    typealias EnvironmentType = Empty
    
    let textColor: UIColor
    let placeholderColor: UIColor
    let value: Int64?
    let minValue: Int64?
    let maxValue: Int64?
    let placeholderText: String
    let amountUpdated: (Int64?) -> Void
    let tag: AnyObject?
    
    init(
        textColor: UIColor,
        placeholderColor: UIColor,
        value: Int64?,
        minValue: Int64?,
        maxValue: Int64?,
        placeholderText: String,
        amountUpdated: @escaping (Int64?) -> Void,
        tag: AnyObject? = nil
    ) {
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.placeholderText = placeholderText
        self.amountUpdated = amountUpdated
        self.tag = tag
    }
    
    static func ==(lhs: AmountFieldComponent, rhs: AmountFieldComponent) -> Bool {
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.maxValue != rhs.maxValue {
            return false
        }
        if lhs.placeholderText != rhs.placeholderText {
            return false
        }
        return true
    }
    
    final class View: UIView, UITextFieldDelegate, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let placeholderView: ComponentView<Empty>
        private let iconView: UIImageView
        private let textField: TextFieldNodeView
        
        private var component: AmountFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.placeholderView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)
            
            self.iconView = UIImageView(image: UIImage(bundleImageName: "Premium/Stars/StarLarge"))

            super.init(frame: frame)

            self.textField.delegate = self
            self.textField.addTarget(self, action: #selector(self.textChanged(_:)), for: .editingChanged)
            
            self.addSubview(self.textField)
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func textChanged(_ sender: Any) {
            let text = self.textField.text ?? ""
            let amount: Int64?
            if !text.isEmpty, let value = Int64(text) {
                amount = value
            } else {
                amount = nil
            }
            self.component?.amountUpdated(amount)
            self.placeholderView.view?.isHidden = !text.isEmpty
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            
            if let component = self.component {
                let amount: Int64?
                if !newText.isEmpty, let value = Int64(newText) {
                    amount = value
                } else {
                    amount = nil
                }
                
                if let amount, let maxAmount = component.maxValue, amount > maxAmount {
                    textField.text = "\(maxAmount)"
                    self.animateError()
                    return false
                }
            }
            return true
        }
        
        func activateInput() {
            self.textField.becomeFirstResponder()
        }
        
        func selectAll() {
            self.textField.selectAll(nil)
        }
        
        func animateError() {
            self.textField.layer.addShakeAnimation()
            let hapticFeedback = HapticFeedback()
            hapticFeedback.error()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                let _ = hapticFeedback
            })
        }
        
        func update(component: AmountFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.textField.textColor = component.textColor
            if let value = component.value {
                self.textField.text = "\(value)"
            } else {
                self.textField.text = ""
            }
            self.textField.font = Font.regular(17.0)
            
            self.textField.keyboardType = .numberPad
            self.textField.returnKeyType = .done
            self.textField.autocorrectionType = .no
            self.textField.autocapitalizationType = .none
                        
            self.component = component
            self.state = state
                       
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            var leftInset: CGFloat = 15.0
            if let icon = self.iconView.image {
                leftInset += icon.size.width + 6.0
                self.iconView.frame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((size.height - icon.size.height) / 2.0)), size: icon.size)
            }
            
            let placeholderSize = self.placeholderView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(
                    Text(
                        text: component.placeholderText,
                        font: Font.regular(17.0),
                        color: component.placeholderColor
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            if let placeholderComponentView = self.placeholderView.view {
                if placeholderComponentView.superview == nil {
                    self.insertSubview(placeholderComponentView, at: 0)
                }
                
                placeholderComponentView.frame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((size.height - placeholderSize.height) / 2.0) + 1.0 - UIScreenPixel), size: placeholderSize)
                
                placeholderComponentView.isHidden = !(self.textField.text ?? "").isEmpty
            }
            
            self.textField.frame = CGRect(x: leftInset, y: 0.0, width: size.width - 30.0, height: 44.0)
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private struct StarsWithdrawConfiguration {
    static var defaultValue: StarsWithdrawConfiguration {
        return StarsWithdrawConfiguration(minWithdrawAmount: nil)
    }
    
    let minWithdrawAmount: Int64?
    
    fileprivate init(minWithdrawAmount: Int64?) {
        self.minWithdrawAmount = minWithdrawAmount
    }
    
    static func with(appConfiguration: AppConfiguration) -> StarsWithdrawConfiguration {
        if let data = appConfiguration.data, let minWithdrawAmount = data["stars_revenue_withdrawal_min"] as? Double {
            return StarsWithdrawConfiguration(minWithdrawAmount: Int64(minWithdrawAmount))
        } else {
            return .defaultValue
        }
    }
}
