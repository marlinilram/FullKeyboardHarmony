import { keyboardController } from '../model/FullKeyboardController';
import { KeyDef, KeyRow, PORTRAIT_LAYOUT, LANDSCAPE_LAYOUT } from '../model/KeyData';

@Entry
@Component
struct Index {
  @StorageLink('isLandscape') isLandscape: boolean = false;
  @StorageLink('keyboardMode') mode: string = 'docked';

  build() {
    Column() {
      if (this.mode !== 'docked') {
        this.Toolbar()
      }
      this.Keyboard()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.colorBackground'))
  }

  @Builder
  Toolbar() {
    Row() {
      Text(this.mode === 'floating' ? '−' : '+')
        .fontSize(18)
        .fontColor($r('app.color.colorText'))
        .width(36)
        .height(28)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (this.mode === 'floating') {
            keyboardController.shrink();
          } else {
            keyboardController.expand();
          }
        })

      Text('≡')
        .fontSize(18)
        .fontColor($r('app.color.colorText'))
        .width(36)
        .height(28)
        .textAlign(TextAlign.Center)
        .gesture(
          PanGesture({ direction: PanDirection.All })
            .onActionUpdate((event: GestureEvent) => {
              keyboardController.movePanelBy(event.offsetX, event.offsetY);
            })
        )

      Text('▼')
        .fontSize(18)
        .fontColor($r('app.color.colorText'))
        .width(36)
        .height(28)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          keyboardController.setMode('docked');
        })
    }
    .width('100%')
    .height(28)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor($r('app.color.colorButton'))
  }

  @Builder
  Keyboard() {
    Column({ space: 2 }) {
      ForEach(this.isLandscape ? LANDSCAPE_LAYOUT : PORTRAIT_LAYOUT, (row: KeyRow, rowIndex: number) => {
        Row({ space: 2 }) {
          ForEach(row, (key: KeyDef, keyIndex: number) => {
            KeyButton({ keyDef: key })
          }, (key: KeyDef, idx: number) => key.label + idx)
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
      }, (row: KeyRow, idx: number) => 'row' + idx)
    }
    .width('100%')
    .height('100%')
    .padding(4)
  }
}

@Component
struct KeyButton {
  @Prop keyDef: KeyDef;
  @StorageLink('ctrlActive') ctrlActive: boolean = false;
  @StorageLink('shiftActive') shiftActive: boolean = false;
  @StorageLink('altActive') altActive: boolean = false;
  @StorageLink('metaActive') metaActive: boolean = false;
  @StorageLink('capsLock') capsLock: boolean = false;
  @StorageLink('numLock') numLock: boolean = false;
  @StorageLink('scrollLock') scrollLock: boolean = false;
  @State pressed: boolean = false;

  private repeatTimer: number = -1;

  private isActive(): boolean {
    if (this.keyDef.type === 'modifier') {
      const code = this.keyDef.keyCode;
      if (code === 113 || code === 114) return this.ctrlActive;
      if (code === 59 || code === 60) return this.shiftActive;
      if (code === 57 || code === 58) return this.altActive;
      if (code === 117 || code === 118) return this.metaActive;
      return this.pressed;
    }
    if (this.keyDef.type === 'lock') {
      const code = this.keyDef.keyCode;
      if (code === 115) return this.capsLock;
      if (code === 143) return this.numLock;
      if (code === 116) return this.scrollLock;
      return this.pressed;
    }
    return this.pressed;
  }

  private isModifierOrLockActive(): boolean {
    return (this.keyDef.type === 'modifier' || this.keyDef.type === 'lock') && this.isActive();
  }

  build() {
    Stack() {
      Text(this.keyDef.label)
        .fontSize(14)
        .fontColor(this.isModifierOrLockActive() ? '#FFFFFFFF' : $r('app.color.colorText'))
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height('100%')
    .layoutWeight(this.keyDef.weight)
    .backgroundColor(this.isModifierOrLockActive() ? $r('app.color.colorAccent') : (this.pressed ? $r('app.color.colorButtonPressed') : $r('app.color.colorButton')))
    .borderRadius(4)
    .onTouch((event: TouchEvent) => {
      switch (event.type) {
        case TouchType.Down:
          this.pressed = true;
          keyboardController.onVirtualKeyDown(this.keyDef);
          break;
        case TouchType.Up:
        case TouchType.Cancel:
          this.pressed = false;
          this.clearRepeat();
          keyboardController.onVirtualKeyUp(this.keyDef);
          break;
      }
    })
  }

  private clearRepeat(): void {
    if (this.repeatTimer !== -1) {
      clearInterval(this.repeatTimer);
      this.repeatTimer = -1;
    }
  }
}
