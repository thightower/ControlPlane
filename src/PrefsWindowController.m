#import "Action.h"
#import "PrefsWindowController.h"
#import "SysConf.h"


// This is here to avoid IB's problem with unknown base classes
@interface ActionTypeHelpTransformer : NSValueTransformer {}
@end
@interface DelayValueTransformer : NSValueTransformer {}
@end
@interface LocalizeTransformer : NSValueTransformer {}
@end
@interface WhenLocalizeTransformer : NSValueTransformer {}
@end


@implementation ActionTypeHelpTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue
{
	return [Action helpTextForActionOfType:(NSString *) theValue];
}

@end

@implementation DelayValueTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)theValue
{
	if (theValue == nil)
		return 0;
	int value = [theValue intValue];

	if (value == 0)
		return NSLocalizedString(@"None", @"Delay value to display for zero seconds");
	else if (value == 1)
		return NSLocalizedString(@"1 second", @"Delay value; number MUST come first");
	else
		return [NSString stringWithFormat:NSLocalizedString(@"%d seconds", "Delay value for >= 2 seconds; number MUST come first"), value];
}

- (id)reverseTransformedValue:(id)theValue
{
	NSString *value = (NSString *) theValue;
	int res = 0;

	if (!value || [value isEqualToString:NSLocalizedString(@"None", @"Delay value to display for zero seconds")])
		res = 0;
	else
		res = [value intValue];

	return [NSNumber numberWithInt:res];
}

@end

@implementation LocalizeTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue
{
	return NSLocalizedString((NSString *) theValue, @"");
}

@end

// XXX: Yar... shouldn't really need this!
@implementation WhenLocalizeTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue
{
	NSString *eng_str = [NSString stringWithFormat:@"On %@", [(NSString *) theValue lowercaseString]];

	return NSLocalizedString(eng_str, @"");
}

@end

@implementation PrefsWindowController

+ (void)initialize
{
	// Register value transformers
	[NSValueTransformer setValueTransformer:[[[ActionTypeHelpTransformer alloc] init] autorelease]
					forName:@"ActionTypeHelpTransformer"];
	[NSValueTransformer setValueTransformer:[[[DelayValueTransformer alloc] init] autorelease]
					forName:@"DelayValueTransformer"];
	[NSValueTransformer setValueTransformer:[[[LocalizeTransformer alloc] init] autorelease]
					forName:@"LocalizeTransformer"];
	[NSValueTransformer setValueTransformer:[[[WhenLocalizeTransformer alloc] init] autorelease]
					forName:@"WhenLocalizeTransformer"];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	blankPrefsView = [[NSView alloc] init];

	return self;
}

- (void)dealloc
{
	[blankPrefsView release];
	[super dealloc];
}

- (void)awakeFromNib
{
	prefsGroups = [[NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"General", @"name",
			NSLocalizedString(@"General", "Preferences section"), @"display_name",
			@"GeneralPrefs", @"icon",
			generalPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"EvidenceSources", @"name",
			NSLocalizedString(@"Evidence Sources", "Preferences section"), @"display_name",
			@"EvidenceSourcesPrefs", @"icon",
			evidenceSourcesPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Rules", @"name",
			NSLocalizedString(@"Rules", "Preferences section"), @"display_name",
			@"RulesPrefs", @"icon",
			rulesPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Actions", @"name",
			NSLocalizedString(@"Actions", "Preferences section"), @"display_name",
			@"ActionsPrefs", @"icon",
			actionsPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Advanced", @"name",
			NSLocalizedString(@"Advanced", "Preferences section"), @"display_name",
			@"AdvancedPrefs", @"icon",
			advancedPrefsView, @"view", nil],
		nil] retain];

	// Init. toolbar
	prefsToolbar = [[NSToolbar alloc] initWithIdentifier:@"prefsToolbar"];
	[prefsToolbar setDelegate:self];
	[prefsToolbar setAllowsUserCustomization:NO];
	[prefsToolbar setAutosavesConfiguration:NO];
        [prefsToolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[prefsWindow setToolbar:prefsToolbar];

	[self switchToView:@"General"];

	// Load up correct localisations
	[whenActionController addObject:
			[NSMutableDictionary dictionaryWithObjectsAndKeys:
				@"Arrival", @"option",
				NSLocalizedString(@"On arrival", @"When an action is triggered"), @"description",
				nil]];
	[whenActionController addObject:
			[NSMutableDictionary dictionaryWithObjectsAndKeys:
				@"Departure", @"option",
				NSLocalizedString(@"On departure", @"When an action is triggered"), @"description",
				nil]];
}

- (IBAction)runPreferences:(id)sender
{
	[newLocationController removeObjects:[newLocationController arrangedObjects]];
	[newLocationController addObjects:[SysConf locationsEnumerate]];
	[newLocationController selectNext:self];

	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:self];
}

// Doesn't strictly belong here, but this is a convenient place for it
- (IBAction)runAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanelWithOptions:
		[NSDictionary dictionaryWithObject:@"" forKey:@"Version"]];
}

#pragma mark Prefs group switching

- (void)switchToViewFromToolbar:(NSToolbarItem *)item
{
	[self switchToView:[item itemIdentifier]];
}

- (void)switchToView:(NSString *)groupId
{
	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject])) {
		if ([[group objectForKey:@"name"] isEqualToString:groupId])
			break;
	}
	if (!group) {
		NSLog(@"Bad prefs group '%@' to switch to!\n", groupId);
		return;
	}

	if (currentPrefsView == [group objectForKey:@"view"])
		return;
	currentPrefsView = [group objectForKey:@"view"];

	[drawer close];

	[prefsWindow setContentView:blankPrefsView];
	[prefsWindow setTitle:[NSString stringWithFormat:@"MarcoPolo - %@", [group objectForKey:@"display_name"]]];
	[self resizeWindowToSize:[currentPrefsView frame].size];

	if ([prefsToolbar respondsToSelector:@selector(setSelectedItemIdentifier:)])
		[prefsToolbar setSelectedItemIdentifier:groupId];
	[prefsWindow setContentView:currentPrefsView];
}

- (void)resizeWindowToSize:(NSSize)size
{
	NSRect frame, contentRect;
	float tbHeight, newHeight, newWidth;

	contentRect = [NSWindow contentRectForFrameRect:[prefsWindow frame]
					      styleMask:[prefsWindow styleMask]];
	tbHeight = (NSHeight(contentRect) - NSHeight([[prefsWindow contentView] frame]));

	newHeight = size.height;
	newWidth = size.width;

	frame = [NSWindow contentRectForFrameRect:[prefsWindow frame]
					styleMask:[prefsWindow styleMask]];

	frame.origin.y += frame.size.height;
	frame.origin.y -= newHeight + tbHeight;
	frame.size.height = newHeight + tbHeight;
	frame.size.width = newWidth;

	frame = [NSWindow frameRectForContentRect:frame
					styleMask:[prefsWindow styleMask]];

	[prefsWindow setFrame:frame display:YES animate:YES];
}

#pragma mark Toolbar delegates

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)groupId willBeInsertedIntoToolbar:(BOOL)flag
{
	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject])) {
		if ([[group objectForKey:@"name"] isEqualToString:groupId])
			break;
	}
	if (!group) {
		NSLog(@"Oops! toolbar delegate is trying to use '%@' as an ID!\n", groupId);
		return nil;
	}

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:groupId];
	[item setLabel:[group objectForKey:@"display_name"]];
	[item setPaletteLabel:[group objectForKey:@"display_name"]];
	[item setImage:[NSImage imageNamed:[group objectForKey:@"icon"]]];
	[item setTarget:self];
	[item setAction:@selector(switchToViewFromToolbar:)];

	return [item autorelease];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[prefsGroups count]];

	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject]))
		[array addObject:[group objectForKey:@"name"]];

	return array;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

#pragma mark Rule creation

- (void)addRule:(id)sender
{
	EvidenceSource *src;
	NSString *name, *type;
	if ([[sender representedObject] isKindOfClass:[NSArray class]]) {
		// specific type
		NSArray *arr = [sender representedObject];
		src = [arr objectAtIndex:0];
		type = [arr objectAtIndex:1];
	} else {
		src = [sender representedObject];
		type = [[src typesOfRulesMatched] objectAtIndex:0];
		type = nil;
	}
	name = [src name];

	int cnt = [mpController pushSuggestionsFromSource:name ofType:type intoController:newRuleParameterController];
	if (cnt < 1) {
#if 0
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"Sorry, don't have any suggestions for you."];
		[alert setAlertStyle:NSInformationalAlertStyle];

		[alert runModal];
		[alert release];
		return;
#endif
	}

	[self setValue:name forKey:@"newRuleType"];
	[self setValue:[src getSuggestionLeadText:type] forKey:@"newRuleWindowText1"];

	[NSApp activateIgnoringOtherApps:YES];
	[newRuleWindow makeKeyAndOrderFront:self];
}

- (IBAction)doAddRule:(id)sender
{
	NSString *loc = [[newLocationController selectedObjects] lastObject];
	NSDictionary *elt = [[newRuleParameterController selectedObjects] lastObject];
	NSString *parm = [elt objectForKey:@"parameter"];
	NSString *desc = [elt objectForKey:@"description"];
	double conf = [newRuleConfidenceSlider doubleValue];

	NSMutableDictionary *new_rule = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithDouble:conf], @"confidence",
		loc, @"location",
		parm, @"parameter",
		[elt objectForKey:@"type"], @"type",
		desc, @"description",
		nil];
	[rulesController addObject:new_rule];

	[newRuleWindow performClose:self];
}

#pragma mark Action creation

- (void)addAction:(id)sender
{
	Class klass = [sender representedObject];
	[self setValue:[Action typeForClass:klass] forKey:@"newActionType"];
	[self setValue:NSLocalizedString([Action typeForClass:klass], @"Action type")
		forKey:@"newActionTypeString"];

	if ([klass conformsToProtocol:@protocol(ActionWithLimitedOptions)]) {
		NSArrayController *loC = newActionLimitedOptionsController;
		[loC removeObjects:[loC arrangedObjects]];
		[loC addObjects:[klass limitedOptions]];
		[loC selectNext:self];

		[self setValue:[klass limitedOptionHelpText] forKey:@"newActionWindowText1"];

		[NSApp activateIgnoringOtherApps:YES];
		[newActionWindowLimitedOptions makeKeyAndOrderFront:self];
		return;
	} else if ([klass conformsToProtocol:@protocol(ActionWithFileParameter)]) {
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setAllowsMultipleSelection:NO];
		[panel setCanChooseDirectories:NO];	// XXX: or YES?
		if ([panel runModal] != NSOKButton)
			return;
		NSString *filename = [panel filename];
		Action *action = [[[klass alloc] initWithFile:filename] autorelease];

		NSMutableDictionary *actionDictionary = [action dictionary];
		[actionsController addObject:actionDictionary];
		[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];
		return;
	}

	Action *action = [[[[sender representedObject] alloc] init] autorelease];
	NSMutableDictionary *actionDictionary = [action dictionary];

	[actionsController addObject:actionDictionary];
	[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];
}

- (IBAction)doAddActionWithLimitedOptions:(id)sender
{
	NSString *opt = [[[newActionLimitedOptionsController selectedObjects] lastObject] valueForKey:@"option"];
	NSString *loc = [[newLocationController selectedObjects] lastObject];

	Class klass = [Action classForType:newActionType];
	Action *action = [[[klass alloc] initWithOption:opt] autorelease];

	NSMutableDictionary *actionDictionary = [action dictionary];
	[actionDictionary setValue:loc forKey:@"location"];
	[actionsController addObject:actionDictionary];
	[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];

	[newActionWindowLimitedOptions performClose:self];
}

@end
