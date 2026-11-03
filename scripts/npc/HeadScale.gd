class_name HeadScale
extends SkeletonModifier3D

# Draws the head a bit bigger than life (CharacterKit). At 37 px tall a true-size head is 5 px
# across, too small to tell a hairstyle or a beard; pixel-art people have big heads for that reason.

@export var bone := "Head"
@export var amount := 1.3


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	var i := skel.find_bone(bone)
	if i >= 0:
		skel.set_bone_pose_scale(i, Vector3.ONE * amount)
