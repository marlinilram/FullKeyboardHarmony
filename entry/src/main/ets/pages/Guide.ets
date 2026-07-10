import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';

@Entry
@Component
struct Guide {
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  private openInputMethodSettings(): void {
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'set_input'
    };
    this.context.startAbility(want)
      .then(() => {
        console.info('Opened input method settings');
      })
      .catch((err: BusinessError) => {
        console.error('Failed to open input method settings', err.code, err.message);
      });
  }

  build() {
    Column({ space: 16 }) {
      Text('DevKeyboard')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.colorText'))

      Image($r('app.media.icon'))
        .width(96)
        .height(96)
        .borderRadius(20)
        .objectFit(ImageFit.Contain)

      Text('使用说明')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.colorText'))
        .margin({ top: 16 })

      Column({ space: 8 }) {
        Text('1. 点击下方按钮进入系统输入法设置。')
          .fontSize(14)
          .fontColor($r('app.color.colorText'))
          .width('100%')
        Text('2. 在列表中找到并启用 DevKeyboard。')
          .fontSize(14)
          .fontColor($r('app.color.colorText'))
          .width('100%')
        Text('3. 将 DevKeyboard 设为默认输入法，或在使用时通过输入法切换按钮选择它。')
          .fontSize(14)
          .fontColor($r('app.color.colorText'))
          .width('100%')
        Text('4. 在任意输入框点击即可调出 DevKeyboard。')
          .fontSize(14)
          .fontColor($r('app.color.colorText'))
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.colorButton'))
      .borderRadius(8)

      Button('进入系统输入法设置', { type: ButtonType.Capsule })
        .width('100%')
        .height(48)
        .backgroundColor($r('app.color.colorAccent'))
        .fontColor('#FFFFFFFF')
        .margin({ top: 24 })
        .onClick(() => this.openInputMethodSettings())
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .backgroundColor($r('app.color.colorBackground'))
  }
}
