import InputMethodExtensionContext from '@ohos.InputMethodExtensionContext';
import inputMethodEngine from '@ohos.inputMethodEngine';
import display from '@ohos.display';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { BusinessError } from '@ohos.base';
import { KeyDef, PORTRAIT_LAYOUT, LANDSCAPE_LAYOUT } from './KeyData';

const TAG = 'FullKeyboard';

export type KeyboardMode = 'docked' | 'floating' | 'shrink';

interface PanelRect {
  width: number;
  height: number;
  x: number;
  y: number;
}

export class FullKeyboardController {
  private static instance: FullKeyboardController | null = null;

  static getInstance(): FullKeyboardController {
    if (!FullKeyboardController.instance) {
      FullKeyboardController.instance = new FullKeyboardController();
    }
    return FullKeyboardController.instance;
  }

  private context: InputMethodExtensionContext | undefined = undefined;
  private inputMethodAbility: inputMethodEngine.InputMethodAbility = inputMethodEngine.getInputMethodAbility();
  private keyboardDelegate: inputMethodEngine.KeyboardDelegate | undefined = undefined;
  private kbController: inputMethodEngine.KeyboardController | undefined = undefined;
  private inputClient: inputMethodEngine.InputClient | undefined = undefined;
  private editorAttribute: inputMethodEngine.EditorAttribute | undefined = undefined;
  private panel: inputMethodEngine.Panel | undefined = undefined;

  private mode: KeyboardMode = 'docked';
  private ctrlActive: boolean = false;
  private shiftActive: boolean = false;
  private altActive: boolean = false;
  private metaActive: boolean = false;
  private capsLock: boolean = false;
  private numLock: boolean = false;
  private scrollLock: boolean = false;
  private physicalAlt: boolean = false;

  private repeatTimer: number = -1;
  private repeatDelayMs: number = 400;
  private repeatIntervalMs: number = 80;
  private lastKey: KeyDef | null = null;
  private physicalKeys: Set<number> = new Set();

  private constructor() {
  }

  public init(context: InputMethodExtensionContext): void {
    this.context = context;
    this.initWindow();
    this.registerListeners();
    this.refreshModifierStorage();
  }

  public destroy(): void {
    this.clearRepeat();
    this.unregisterListeners();
    if (this.panel) {
      try {
        this.inputMethodAbility.destroyPanel(this.panel);
      } catch (err) {
        this.logError('destroyPanel', err as BusinessError);
      }
      this.panel = undefined;
    }
    if (this.context) {
      this.context.destroy();
      this.context = undefined;
    }
  }

  // ---------- Panel creation ----------

  private initWindow(): void {
    if (!this.context) {
      return;
    }
    const dis = display.getDefaultDisplaySync();
    const dWidth = dis.width;
    const dHeight = dis.height;
    const isLandscape = dWidth > dHeight;
    AppStorage.setOrCreate('windowWidth', dWidth);
    AppStorage.setOrCreate('windowHeight', dHeight);
    AppStorage.setOrCreate('isLandscape', isLandscape);

    const panelInfo: inputMethodEngine.PanelInfo = {
      type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
      flag: this.mode === 'docked' ? inputMethodEngine.PanelFlag.FLG_FIXED : inputMethodEngine.PanelFlag.FLG_FLOATING
    };

    const rect: PanelRect = this.computePanelRect(dWidth, dHeight);
    const width = rect.width;
    const height = rect.height;
    const x = rect.x;
    const y = rect.y;

    this.inputMethodAbility.createPanel(this.context, panelInfo).then((panel: inputMethodEngine.Panel) => {
      this.panel = panel;
      this.panel.resize(width, height).then(() => {
        this.panel!.moveTo(x, y).then(() => {
          this.panel!.setUiContent('pages/Index').then(() => {
            console.info(TAG, 'panel loaded');
          }).catch((err: BusinessError) => this.logError('setUiContent', err));
        }).catch((err: BusinessError) => this.logError('moveTo', err));
      }).catch((err: BusinessError) => this.logError('resize', err));
    }).catch((err: BusinessError) => this.logError('createPanel', err));
  }

  private computePanelRect(dWidth: number, dHeight: number): PanelRect {
    const isLandscape = dWidth > dHeight;
    if (this.mode === 'shrink') {
      const w = isLandscape ? Math.floor(dWidth * 0.4) : Math.floor(dWidth * 0.55);
      const h = isLandscape ? 100 : 140;
      return { width: w, height: h, x: Math.floor((dWidth - w) / 2), y: Math.floor((dHeight - h) / 2) };
    }
    if (this.mode === 'floating') {
      const rate = isLandscape ? 0.55 : 0.9;
      const w = Math.floor(dWidth * rate);
      const h = isLandscape ? 180 : 260;
      return { width: w, height: h, x: Math.floor((dWidth - w) / 2), y: Math.floor(dHeight * 0.45) };
    }
    // docked
    const rate = isLandscape ? 0.4 : 0.45;
    const h = Math.floor(dHeight * rate);
    return { width: dWidth, height: h, x: 0, y: dHeight - h };
  }

  private recreatePanel(): void {
    if (this.panel) {
      try {
        this.inputMethodAbility.destroyPanel(this.panel);
      } catch (err) {
        this.logError('destroyPanel', err as BusinessError);
      }
      this.panel = undefined;
    }
    this.initWindow();
  }

  public setMode(mode: KeyboardMode): void {
    if (this.mode === mode) {
      return;
    }
    this.mode = mode;
    AppStorage.setOrCreate('keyboardMode', mode);
    this.recreatePanel();
  }

  public getMode(): KeyboardMode {
    return this.mode;
  }

  public toggleFloating(): void {
    if (this.mode === 'docked') {
      this.setMode('floating');
    } else {
      this.setMode('docked');
    }
  }

  public shrink(): void {
    this.setMode('shrink');
  }

  public expand(): void {
    this.setMode('floating');
  }

  public movePanelBy(dx: number, dy: number): void {
    if (!this.panel || this.mode === 'docked') {
      return;
    }
    // actual current position is not exposed; approximate by re-computing from display
    const dis = display.getDefaultDisplaySync();
    const rect = this.computePanelRect(dis.width, dis.height);
    const nx = Math.max(0, Math.min(dis.width - rect.width, rect.x + dx));
    const ny = Math.max(0, Math.min(dis.height - rect.height, rect.y + dy));
    this.panel.moveTo(nx, ny).catch((err: BusinessError) => this.logError('moveBy', err));
  }

  // ---------- Listeners ----------

  private onInputStartCallback = (kbController: inputMethodEngine.KeyboardController, textInputClient: inputMethodEngine.InputClient) => {
    this.kbController = kbController;
    this.inputClient = textInputClient;
    try {
      this.editorAttribute = textInputClient.getEditorAttributeSync();
    } catch (err) {
      this.logError('getEditorAttributeSync', err as BusinessError);
    }
    AppStorage.setOrCreate('enterKeyType', this.editorAttribute?.enterKeyType ?? 0);
  };

  private onInputStopCallback = () => {
    this.destroy();
  };

  private onKeyDownCallback = (event: inputMethodEngine.KeyEvent): boolean => {
    return this.onPhysicalKeyDown(event);
  };

  private onKeyUpCallback = (event: inputMethodEngine.KeyEvent): boolean => {
    return this.onPhysicalKeyUp(event);
  };

  private registerListeners(): void {
    this.inputMethodAbility.on('inputStart', this.onInputStartCallback);
    this.inputMethodAbility.on('inputStop', this.onInputStopCallback);

    this.keyboardDelegate = inputMethodEngine.getKeyboardDelegate();
    this.keyboardDelegate.on('keyDown', this.onKeyDownCallback);
    this.keyboardDelegate.on('keyUp', this.onKeyUpCallback);
  }

  private unregisterListeners(): void {
    this.inputMethodAbility.off('inputStart', this.onInputStartCallback);
    this.inputMethodAbility.off('inputStop', this.onInputStopCallback);
    if (this.keyboardDelegate) {
      this.keyboardDelegate.off('keyDown', this.onKeyDownCallback);
      this.keyboardDelegate.off('keyUp', this.onKeyUpCallback);
    }
  }

  // ---------- Virtual key handling (from UI) ----------

  public onVirtualKeyDown(key: KeyDef): void {
    this.lastKey = key;
    if (this.isModifierKey(key.keyCode)) {
      this.toggleModifier(key.keyCode);
      return;
    }
    if (this.isLockKey(key.keyCode)) {
      this.toggleLock(key.keyCode);
      this.executeKeyAction(key);
      return;
    }
    this.executeKeyAction(key);
    this.startRepeat(key);
  }

  public onVirtualKeyUp(key: KeyDef): void {
    this.clearRepeat();
    this.lastKey = null;
  }

  private isRepeatableKey(kc: number): boolean {
    return kc === 67 || kc === 112 || kc === 19 || kc === 20 || kc === 21 || kc === 22 || kc === 122 || kc === 123;
  }

  private startRepeat(key: KeyDef): void {
    if (!this.isRepeatableKey(key.keyCode)) {
      return;
    }
    this.clearRepeat();
    this.repeatTimer = setTimeout(() => {
      this.repeatTimer = setInterval(() => {
        this.executeKeyAction(key);
      }, this.repeatIntervalMs);
    }, this.repeatDelayMs);
  }

  private clearRepeat(): void {
    if (this.repeatTimer !== -1) {
      clearTimeout(this.repeatTimer);
      clearInterval(this.repeatTimer);
      this.repeatTimer = -1;
    }
  }

  private handleCtrlCombo(kc: number): boolean {
    if (!this.ctrlActive || !this.inputClient) {
      return false;
    }
    switch (kc) {
      case 29: // A
        this.inputClient.sendExtendAction(inputMethodEngine.ExtendAction.SELECT_ALL)
          .catch((err: BusinessError) => this.logError('selectAll', err));
        return true;
      case 31: // C
        this.inputClient.sendExtendAction(inputMethodEngine.ExtendAction.COPY)
          .catch((err: BusinessError) => this.logError('copy', err));
        return true;
      case 50: // V
        this.inputClient.sendExtendAction(inputMethodEngine.ExtendAction.PASTE)
          .catch((err: BusinessError) => this.logError('paste', err));
        return true;
      case 52: // X
        this.inputClient.sendExtendAction(inputMethodEngine.ExtendAction.CUT)
          .catch((err: BusinessError) => this.logError('cut', err));
        return true;
      default:
        return false;
    }
  }

  // For terminal scenarios (tmux, shell, xterm.js): Ctrl+Letter emits the
  // corresponding C0 control character (Ctrl+A -> 0x01, ..., Ctrl+Z -> 0x1A).
  // This is the best available workaround because HarmonyOS IME Kit does not
  // expose an API to inject raw KeyEvent/scanCode into the target app.
  private sendCtrlChar(kc: number): boolean {
    if (!this.ctrlActive || !this.inputClient) {
      return false;
    }
    if (kc >= 29 && kc <= 54) { // Android KEYCODE_A .. KEYCODE_Z
      const ctrlChar = String.fromCharCode((kc - 29) + 1);
      this.inputClient.insertText(ctrlChar);
      return true;
    }
    return false;
  }

  private executeKeyAction(key: KeyDef): void {
    if (!this.inputClient) {
      return;
    }
    const kc = key.keyCode;

    if (this.handleCtrlCombo(kc)) {
      return;
    }
    if (this.sendCtrlChar(kc)) {
      return;
    }

    // Navigation / editing
    if (kc === 67) { // Android KEYCODE_DEL
      this.inputClient.deleteBackward(1);
      return;
    }
    if (kc === 112) { // Android KEYCODE_FORWARD_DEL
      this.inputClient.deleteForward(1);
      return;
    }
    if (kc === 19) { this.inputClient.moveCursor(inputMethodEngine.Direction.CURSOR_UP); return; }
    if (kc === 20) { this.inputClient.moveCursor(inputMethodEngine.Direction.CURSOR_DOWN); return; }
    if (kc === 21) { this.inputClient.moveCursor(inputMethodEngine.Direction.CURSOR_LEFT); return; }
    if (kc === 22) { this.inputClient.moveCursor(inputMethodEngine.Direction.CURSOR_RIGHT); return; }
    if (kc === 122) { // HOME
      try { this.inputClient.selectByRange({ start: 0, end: 0 }); } catch (err) { this.logError('home', err as BusinessError); }
      return;
    }
    if (kc === 123) { // END
      try { this.inputClient.selectByRange({ start: 10000, end: 10000 }); } catch (err) { this.logError('end', err as BusinessError); }
      return;
    }
    if (kc === 61) { // TAB
      this.inputClient.insertText('\t');
      return;
    }
    if (kc === 66) { // ENTER
      if (this.editorAttribute) {
        this.inputClient.sendKeyFunction(this.editorAttribute.enterKeyType);
      }
      return;
    }
    if (kc === 62) { // SPACE
      this.inputClient.insertText(' ');
      return;
    }
    if (kc === 111) { // ESC
      this.kbController?.hide();
      return;
    }
    if (kc === 204) { // LANGUAGE_SWITCH
      // Framework does not expose a public switch API from InputMethodAbility.
      // Hide keyboard so the user can pick another input method.
      this.kbController?.hide();
      return;
    }
    if (kc === 82) { // MENU
      return;
    }
    if ((kc >= 24 && kc <= 25) || kc === 164) { // volume / mute - ignore
      return;
    }

    // Printable character
    const text = this.resolveText(key);
    if (text.length > 0) {
      this.inputClient.insertText(text);
    }
  }

  private resolveText(key: KeyDef): string {
    const label = key.label;
    const shift = this.shiftActive || this.capsLock;
    const parts = label.split(/\s+/);
    if (parts.length >= 2) {
      return shift ? parts[1] : parts[0];
    }
    if (label.length === 1 && label >= 'A' && label <= 'Z') {
      return shift ? label : label.toLowerCase();
    }
    return label;
  }

  // ---------- Modifiers / Locks ----------

  private isModifierKey(androidKeyCode: number): boolean {
    return [113, 114, 59, 60, 57, 58, 117, 118].includes(androidKeyCode);
  }

  private isLockKey(androidKeyCode: number): boolean {
    return [115, 116, 143].includes(androidKeyCode);
  }

  private toggleModifier(androidKeyCode: number): void {
    if (androidKeyCode === 113 || androidKeyCode === 114) this.ctrlActive = !this.ctrlActive;
    if (androidKeyCode === 59 || androidKeyCode === 60) this.shiftActive = !this.shiftActive;
    if (androidKeyCode === 57 || androidKeyCode === 58) this.altActive = !this.altActive;
    if (androidKeyCode === 117 || androidKeyCode === 118) this.metaActive = !this.metaActive;
    this.refreshModifierStorage();
  }

  private toggleLock(androidKeyCode: number): void {
    if (androidKeyCode === 115) this.capsLock = !this.capsLock;
    if (androidKeyCode === 143) this.numLock = !this.numLock;
    if (androidKeyCode === 116) this.scrollLock = !this.scrollLock;
    this.refreshModifierStorage();
  }

  private refreshModifierStorage(): void {
    AppStorage.setOrCreate('ctrlActive', this.ctrlActive);
    AppStorage.setOrCreate('shiftActive', this.shiftActive);
    AppStorage.setOrCreate('altActive', this.altActive);
    AppStorage.setOrCreate('metaActive', this.metaActive);
    AppStorage.setOrCreate('capsLock', this.capsLock);
    AppStorage.setOrCreate('numLock', this.numLock);
    AppStorage.setOrCreate('scrollLock', this.scrollLock);
  }

  public isModifierActive(androidKeyCode: number): boolean {
    if (androidKeyCode === 113 || androidKeyCode === 114) return this.ctrlActive;
    if (androidKeyCode === 59 || androidKeyCode === 60) return this.shiftActive;
    if (androidKeyCode === 57 || androidKeyCode === 58) return this.altActive;
    if (androidKeyCode === 117 || androidKeyCode === 118) return this.metaActive;
    return false;
  }

  public isLockActive(androidKeyCode: number): boolean {
    if (androidKeyCode === 115) return this.capsLock;
    if (androidKeyCode === 143) return this.numLock;
    if (androidKeyCode === 116) return this.scrollLock;
    return false;
  }

  // ---------- Physical keyboard handling ----------

  private onPhysicalKeyDown(event: inputMethodEngine.KeyEvent): boolean {
    const code = event.keyCode;
    this.physicalKeys.add(code);
    this.updatePhysicalAlt(code, true);

    if (this.isPhysicalModifier(code)) {
      this.setPhysicalModifier(code, true);
      return false; // let system handle modifier
    }

    if (this.isPhysicalLock(code)) {
      return false;
    }

    // When physical Alt is held, try to output the alternate character and consume it.
    if (this.physicalAlt) {
      const altChar = this.getPhysicalAltChar(code);
      if (altChar) {
        this.inputClient?.insertText(altChar);
        return true;
      }
    }

    if (this.handleCtrlCombo(code)) {
      return true;
    }
    if (this.sendCtrlChar(code)) {
      return true;
    }

    const value = this.getPhysicalKeyValue(code);
    if (value === '') {
      return false;
    }
    if (this.processPhysicalFunction(code)) {
      return true;
    }
    this.inputClient?.insertText(value);
    return true;
  }

  private onPhysicalKeyUp(event: inputMethodEngine.KeyEvent): boolean {
    const code = event.keyCode;
    this.physicalKeys.delete(code);
    this.updatePhysicalAlt(code, false);
    if (this.isPhysicalModifier(code)) {
      this.setPhysicalModifier(code, false);
    }
    return false;
  }

  private isPhysicalModifier(code: number): boolean {
    return code === KeyCode.KEYCODE_CTRL_LEFT || code === KeyCode.KEYCODE_CTRL_RIGHT ||
      code === KeyCode.KEYCODE_SHIFT_LEFT || code === KeyCode.KEYCODE_SHIFT_RIGHT ||
      code === KeyCode.KEYCODE_ALT_LEFT || code === KeyCode.KEYCODE_ALT_RIGHT ||
      code === KeyCode.KEYCODE_META_LEFT || code === KeyCode.KEYCODE_META_RIGHT;
  }

  private isPhysicalLock(code: number): boolean {
    return code === KeyCode.KEYCODE_CAPS_LOCK || code === KeyCode.KEYCODE_NUM_LOCK || code === KeyCode.KEYCODE_SCROLL_LOCK;
  }

  private setPhysicalModifier(code: number, down: boolean): void {
    if (code === KeyCode.KEYCODE_CTRL_LEFT || code === KeyCode.KEYCODE_CTRL_RIGHT) this.ctrlActive = down;
    if (code === KeyCode.KEYCODE_SHIFT_LEFT || code === KeyCode.KEYCODE_SHIFT_RIGHT) this.shiftActive = down;
    if (code === KeyCode.KEYCODE_ALT_LEFT || code === KeyCode.KEYCODE_ALT_RIGHT) this.altActive = down;
    if (code === KeyCode.KEYCODE_META_LEFT || code === KeyCode.KEYCODE_META_RIGHT) this.metaActive = down;
    this.refreshModifierStorage();
  }

  private updatePhysicalAlt(code: number, down: boolean): void {
    if (code === KeyCode.KEYCODE_ALT_LEFT || code === KeyCode.KEYCODE_ALT_RIGHT) {
      this.physicalAlt = down;
    }
  }

  private getPhysicalKeyValue(code: number): string {
    // Letters
    if (code >= KeyCode.KEYCODE_A && code <= KeyCode.KEYCODE_Z) {
      const ch = String.fromCharCode('A'.charCodeAt(0) + (code - KeyCode.KEYCODE_A));
      const upper = this.shiftActive || this.capsLock;
      return upper ? ch : ch.toLowerCase();
    }
    // Numbers
    if (code >= KeyCode.KEYCODE_0 && code <= KeyCode.KEYCODE_9) {
      const digit = String.fromCharCode('0'.charCodeAt(0) + (code - KeyCode.KEYCODE_0));
      if (this.shiftActive) {
        const shifted = ')!@#$%^&*(';
        return shifted.charAt(code - KeyCode.KEYCODE_0);
      }
      return digit;
    }
    switch (code) {
      case KeyCode.KEYCODE_SPACE: return ' ';
      case KeyCode.KEYCODE_TAB: return '\t';
      case KeyCode.KEYCODE_ENTER: return '\n';
      case KeyCode.KEYCODE_GRAVE: return this.shiftActive ? '~' : '`';
      case KeyCode.KEYCODE_MINUS: return this.shiftActive ? '_' : '-';
      case KeyCode.KEYCODE_EQUALS: return this.shiftActive ? '+' : '=';
      case KeyCode.KEYCODE_LEFT_BRACKET: return this.shiftActive ? '{' : '[';
      case KeyCode.KEYCODE_RIGHT_BRACKET: return this.shiftActive ? '}' : ']';
      case KeyCode.KEYCODE_BACKSLASH: return this.shiftActive ? '|' : '\\';
      case KeyCode.KEYCODE_SEMICOLON: return this.shiftActive ? ':' : ';';
      case KeyCode.KEYCODE_APOSTROPHE: return this.shiftActive ? '"' : "'";
      case KeyCode.KEYCODE_SLASH: return this.shiftActive ? '?' : '/';
      case KeyCode.KEYCODE_COMMA: return this.shiftActive ? '<' : ',';
      case KeyCode.KEYCODE_PERIOD: return this.shiftActive ? '>' : '.';
      default: return '';
    }
  }

  private getPhysicalAltChar(code: number): string {
    switch (code) {
      case KeyCode.KEYCODE_A: return 'á';
      case KeyCode.KEYCODE_E: return 'é';
      case KeyCode.KEYCODE_I: return 'í';
      case KeyCode.KEYCODE_O: return 'ó';
      case KeyCode.KEYCODE_U: return 'ú';
      case KeyCode.KEYCODE_N: return 'ñ';
      case KeyCode.KEYCODE_Q: return 'ä';
      case KeyCode.KEYCODE_S: return 'ß';
      case KeyCode.KEYCODE_1: return '¡';
      case KeyCode.KEYCODE_2: return '™';
      case KeyCode.KEYCODE_3: return '£';
      case KeyCode.KEYCODE_4: return '¢';
      case KeyCode.KEYCODE_5: return '∞';
      case KeyCode.KEYCODE_6: return '§';
      case KeyCode.KEYCODE_7: return '¶';
      case KeyCode.KEYCODE_8: return '•';
      case KeyCode.KEYCODE_9: return 'ª';
      case KeyCode.KEYCODE_0: return 'º';
      default: return '';
    }
  }

  private processPhysicalFunction(code: number): boolean {
    if (code === KeyCode.KEYCODE_DEL) {
      this.inputClient?.deleteBackward(1);
      return true;
    }
    if (code === KeyCode.KEYCODE_FORWARD_DEL) {
      this.inputClient?.deleteForward(1);
      return true;
    }
    if (code === KeyCode.KEYCODE_DPAD_UP) { this.inputClient?.moveCursor(inputMethodEngine.Direction.CURSOR_UP); return true; }
    if (code === KeyCode.KEYCODE_DPAD_DOWN) { this.inputClient?.moveCursor(inputMethodEngine.Direction.CURSOR_DOWN); return true; }
    if (code === KeyCode.KEYCODE_DPAD_LEFT) { this.inputClient?.moveCursor(inputMethodEngine.Direction.CURSOR_LEFT); return true; }
    if (code === KeyCode.KEYCODE_DPAD_RIGHT) { this.inputClient?.moveCursor(inputMethodEngine.Direction.CURSOR_RIGHT); return true; }
    if (code === KeyCode.KEYCODE_MOVE_HOME) { try { this.inputClient?.selectByRange({ start: 0, end: 0 }); } catch (err) { this.logError('home', err as BusinessError); } return true; }
    if (code === KeyCode.KEYCODE_MOVE_END) { try { this.inputClient?.selectByRange({ start: 10000, end: 10000 }); } catch (err) { this.logError('end', err as BusinessError); } return true; }
    return false;
  }

  private logError(msg: string, err: BusinessError): void {
    console.error(TAG, `${msg} error: ${err.code} ${err.message}`);
  }
}

export const keyboardController: FullKeyboardController = FullKeyboardController.getInstance();
