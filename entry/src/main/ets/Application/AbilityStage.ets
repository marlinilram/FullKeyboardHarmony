import AbilityStage from '@ohos.app.ability.AbilityStage';
import Want from '@ohos.app.ability.Want';

export default class EntryAbilityStage extends AbilityStage {
  onCreate(): void {
    // application-level initialization if needed
  }

  onAcceptWant(want: Want): string {
    return want.abilityName ?? '';
  }
}
