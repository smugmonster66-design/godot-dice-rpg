# DieObject System Migration Guide

## Overview

This refactoring introduces a new **DieObject** system that separates die visuals into dedicated scene components, eliminating the need for complex drag preview creation code. 

### Key Changes

| Before | After |
|--------|-------|
| `DieVisual` class did everything | `DieObjectBase` → `CombatDieObject` / `PoolDieObject` |
| Drag previews built from scratch in code | `DieResource.instantiate_combat_visual()` / `instantiate_pool_visual()` |
| Textures applied via find_child() | Textures applied via scene node references |
| One visual type for all contexts | Combat (rolled values) vs Pool (max values) |

---

## New File Structure

```
scripts/ui/components/dice/
├── die_object_base.gd      # Base class - shared logic
├── combat_die_object.gd    # Combat subclass - rolled values
└── pool_die_object.gd      # Pool subclass - max values

scenes/ui/components/dice/
├── die_object_base.tscn    # Base scene template
├── combat/
│   ├── combat_die_object_base.tscn
│   ├── combat_die_d4.tscn
│   ├── combat_die_d6.tscn
│   ├── combat_die_d8.tscn
│   ├── combat_die_d10.tscn
│   ├── combat_die_d12.tscn
│   └── combat_die_d20.tscn
└── pool/
    ├── pool_die_object_base.tscn
    ├── pool_die_d4.tscn
    ├── pool_die_d6.tscn
    ├── pool_die_d8.tscn
    ├── pool_die_d10.tscn
    ├── pool_die_d12.tscn
    └── pool_die_d20.tscn

resources/data/
└── die_resource.gd         # Updated with scene exports
```

---

## Editor Setup Instructions

### Step 1: Copy New Files to Project

Copy all files from the output to your Godot project, maintaining the directory structure.

### Step 2: Fix Scene UIDs (IMPORTANT)

Godot will need to regenerate UIDs for the new scenes. After copying:

1. Open Godot and let it import the new files
2. If you see UID conflicts, delete the `.godot/uid_cache.bin` file
3. Restart Godot

### Step 3: Customize ValueLabel Positioning Per Die Type

The base scenes have centered ValueLabels. To match your existing die_face scenes:

**For each combat/pool die scene (e.g., `combat_die_d20.tscn`):**

1. Open the scene in Godot
2. Select the `ValueLabel` node
3. Adjust the offset properties to match your die_face_d20.tscn positioning:
   - For D20: `offset_left: 23, offset_top: 32, offset_right: 63, offset_bottom: 115`
   - For D6: centered is usually fine
4. Save the scene

### Step 4: Add Animations to AnimationPlayer (Optional)

Each DieObject scene has an AnimationPlayer. Add these animations for polish:

| Animation Name | Purpose | Suggested Implementation |
|----------------|---------|-------------------------|
| `idle` | Default state | Empty or subtle pulse |
| `hover` | Mouse hover | Scale to 1.05 over 0.1s |
| `pickup` | Drag start | Scale to 1.1, brighten |
| `snap_back` | Drag cancelled | Bounce back with overshoot |
| `place` | Dropped in slot | Quick scale pulse |
| `reject` | Invalid action | Horizontal shake |
| `roll_complete` | After roll (combat) | Flash/pulse |
| `locked` | Die is locked | Desaturate |

**To add animations:**

1. Open a die scene (e.g., `combat_die_d6.tscn`)
2. Select the `AnimationPlayer` node
3. Click "Animation" → "New"
4. Name it (e.g., "hover")
5. Add tracks for `.:scale`, `.:modulate`, etc.
6. Save

### Step 5: Update Existing DieResource .tres Files (Optional)

Your existing `.tres` files will still work because `DieResource` auto-selects scenes based on `die_type`. However, for custom dice with unique visuals, you can explicitly set scenes:

1. Open a DieResource `.tres` file (e.g., `d12_frost_hammer_die.tres`)
2. In Inspector, expand "Die Object Scenes"
3. Drag the appropriate scene to `Combat Die Scene` and/or `Pool Die Scene`
4. Save

---

## Code Migration

### Replacing DieVisual Usage

**Before:**
```gdscript
var visual = die_visual_scene.instantiate()
visual.set_die(die)
add_child(visual)
```

**After:**
```gdscript
var visual = die.instantiate_combat_visual()  # or instantiate_pool_visual()
add_child(visual)
```

### Replacing Drag Preview Creation

**Before:**
```gdscript
func _create_drag_preview() -> Control:
    var wrapper = Control.new()
    var scene = load("res://scenes/ui/components/dice/die_face_d%d.tscn" % die_data.die_type)
    var face = scene.instantiate()
    # ... 50+ lines of manual setup ...
    return wrapper
```

**After:**
```gdscript
func _create_drag_preview() -> Control:
    return die_resource.instantiate_combat_visual().create_drag_preview()
```

### Handling Combat vs Pool Context

**Combat (shows rolled value):**
```gdscript
var combat_die = die.instantiate_combat_visual()
combat_die.update_after_roll()  # Refresh display after rolling
```

**Pool/Inventory (shows max value):**
```gdscript
var pool_die = die.instantiate_pool_visual()
pool_die.show_affix_count()  # Optional: show affix indicator
```

---

## Signal Reference

### DieObjectBase Signals
- `drag_requested(die_object)` - User wants to drag (parent decides)
- `clicked(die_object)` - Click without drag
- `drag_ended(die_object, was_placed)` - Drag finished

### CombatDieObject Signals
- `roll_animation_finished(die_object)` - Roll animation done

### PoolDieObject Signals  
- `reorder_completed(die_object, new_index)` - Reorder finished

---

## Deprecation Notes

The following are now **deprecated** but still functional:

- `DieVisual` class - Replace with `CombatDieObject` or `PoolDieObject`
- `die_visual.tscn` - Replace with new die object scenes
- `show_max_value` property on DieVisual - Use `PoolDieObject` instead

---

## Troubleshooting

### "Cannot find node FillTexture"
- Ensure the scene has nodes named exactly `FillTexture`, `StrokeTexture`, `ValueLabel`
- Check that nodes aren't renamed or moved

### Textures not appearing
- Verify `DieResource.fill_texture` and `stroke_texture` are set
- Check that textures exist at the specified paths

### Drag preview looks wrong
- Override `create_drag_preview()` in your subclass if needed
- Ensure `base_size` matches your texture dimensions

### Animations not playing
- Verify animation names match exactly (case-sensitive)
- Check AnimationPlayer has the animations defined
- Fallback tween animations play if AnimationPlayer animations are missing
