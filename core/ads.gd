extends Node
## AdMob (Poing plugin), placed to respect the player:
## - banner on the game picker only, never over play
## - interstitial only at a natural break (after a game-over, when you tap Again / Games),
##   at most every INTERSTITIAL_EVERY game-overs, MIN_GAP s apart, never in the first FIRST_FREE s
## - rewarded "one more life": offered on the game-over card, opt-in, once per run
## Desktop builds have no ads (everything below no-ops).
##
## BEFORE PUBLISHING: replace the Google TEST ids below with your own ad unit ids, and set
## Project Settings > admob/general/android/app_id to your AdMob app id (defaults to the test app id).

const IDS := {   # ponytail: Google's official test ids
	"banner": "ca-app-pub-3940256099942544/6300978111",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
}
const INTERSTITIAL_EVERY := 3
const MIN_GAP := 90.0
const FIRST_FREE := 120.0

var enabled := false
var _started := false
var _banner: AdView
var _banner_wanted := false
var _inter: InterstitialAd
var _reward: RewardedAd
var _inter_loader: InterstitialAdLoader
var _reward_loader: RewardedAdLoader
var _game_overs := 0
var _last_inter := -1000.0

func _ready() -> void:
	enabled = OS.get_name() in ["Android", "iOS"]
	if enabled:
		_request_consent()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------- consent (GDPR/UMP) then init ----------
func _request_consent() -> void:
	var consent := UserMessagingPlatform.consent_information
	consent.update(ConsentRequestParameters.new(),
		func() -> void:
			if consent.get_is_consent_form_available() \
					and consent.get_consent_status() == consent.ConsentStatus.REQUIRED:
				UserMessagingPlatform.load_consent_form(
					func(form: ConsentForm) -> void: form.show(func(_e: FormError) -> void: _init_sdk()),
					func(_e: FormError) -> void: _init_sdk())
			else:
				_init_sdk(),
		func(_e: FormError) -> void: _init_sdk())

func _init_sdk() -> void:
	if _started:
		return
	_started = true
	var cfg := RequestConfiguration.new()
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G   # family-safe ads only
	MobileAds.set_request_configuration(cfg)
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_load_interstitial()
		_load_rewarded()
		if _banner_wanted:
			show_banner()
	MobileAds.initialize(on_init)

# ---------- banner (menu only) ----------
func show_banner() -> void:
	_banner_wanted = true
	if not enabled or not _started:
		return
	if _banner == null:
		var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		_banner = AdView.new(IDS.banner, size, AdPosition.BOTTOM)
		_banner.ad_listener = AdListener.new()
		_banner.load_ad(AdRequest.new())
	else:
		_banner.show()

func hide_banner() -> void:
	_banner_wanted = false
	if _banner:
		_banner.hide()

# ---------- interstitial (natural breaks only) ----------
func _load_interstitial() -> void:
	if not enabled:
		return
	if _inter_loader == null:
		_inter_loader = InterstitialAdLoader.new()
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void: _inter = ad
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void: _inter = null
	_inter_loader.load(IDS.interstitial, AdRequest.new(), cb)

## Call after a game-over, when the player chooses Again / Games. then() runs after the ad (or at once).
func game_over_break(then: Callable) -> void:
	_game_overs += 1
	var eligible := enabled and _inter != null \
		and _game_overs % INTERSTITIAL_EVERY == 0 \
		and _now() - _last_inter >= MIN_GAP and _now() >= FIRST_FREE
	if not eligible:
		then.call()
		return
	var ad := _inter
	_inter = null
	var cbs := FullScreenContentCallback.new()
	var finish := func() -> void:
		ad.destroy()
		_last_inter = _now()
		_load_interstitial()
		then.call()
	cbs.on_ad_dismissed_full_screen_content = finish
	cbs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = cbs
	ad.show()

# ---------- rewarded (opt-in) ----------
func _load_rewarded() -> void:
	if not enabled:
		return
	if _reward_loader == null:
		_reward_loader = RewardedAdLoader.new()
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void: _reward = ad
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void: _reward = null
	_reward_loader.load(IDS.rewarded, AdRequest.new(), cb)

func reward_ready() -> bool:
	return enabled and _reward != null

## Shows the rewarded ad; on_reward runs only if the player watched it through.
func show_reward(on_reward: Callable, on_closed: Callable) -> void:
	if not reward_ready():
		on_closed.call()
		return
	var ad := _reward
	_reward = null
	var earned := [false]
	var cbs := FullScreenContentCallback.new()
	var finish := func() -> void:
		ad.destroy()
		_load_rewarded()
		if earned[0]:
			on_reward.call()
		else:
			on_closed.call()
	cbs.on_ad_dismissed_full_screen_content = finish
	cbs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = cbs
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(listener)
