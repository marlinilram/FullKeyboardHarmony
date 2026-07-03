import InputMethodExtensionAbility from '@ohos.InputMethodExtensionAbility';
import InputMethodExtensionContext from '@ohos.InputMethodExtensionContext';
import Want from '@ohos.app.ability.Want';
import { keyboardController } from '../model/FullKeyboardController';

export default class FullKeyboardAbility extends InputMethodExtensionAbility {
  onCreate(want: Want): void {
    keyboardController.init(this.context as InputMethodExtensionContext);
  }

  onDestroy(): void {
    keyboardController.destroy();
  }
}
