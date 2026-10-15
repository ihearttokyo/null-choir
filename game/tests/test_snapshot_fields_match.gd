extends SceneTree

const Candidate = preload("res://tests/ossuary_second_loop_witness.gd")

static func stored_image(value):
	if value is Array:
		var result: Array = []
		for item in value: result.append(stored_image(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = stored_image(value[key])
		return result
	if typeof(value) == TYPE_OBJECT:
		return {"object_id":value.get_instance_id() if is_instance_valid(value) else 0}
	return value

# NaN scalars compare by classification; math/packed fixtures use finite values or infinity.
static func same_image(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected): return false
	if actual is Array:
		if actual.is_typed() or expected.is_typed() or actual.is_read_only() or expected.is_read_only() or actual.size() != expected.size(): return false
		for index in actual.size():
			if not same_image(actual[index],expected[index]): return false
		return true
	if actual is Dictionary:
		if actual.is_typed() or expected.is_typed() or actual.is_read_only() or expected.is_read_only() or actual.size() != expected.size(): return false
		var actual_keys: Array = actual.keys()
		var expected_keys: Array = expected.keys()
		for index in actual_keys.size():
			if not is_same(actual_keys[index],expected_keys[index]) or not same_image(actual[actual_keys[index]],expected[expected_keys[index]]): return false
		return true
	if typeof(actual) == TYPE_FLOAT and is_nan(actual): return is_nan(expected)
	return actual == expected

func expect(condition: bool, label: String) -> bool:
	if not condition: push_error("FAIL snapshot parity: "+label)
	return condition

class Holder:
	extends RefCounted
	var value: Variant

func match_parity(value: Variant, image: Variant, label: String) -> bool:
	var holder = Holder.new()
	holder.value = value
	var expected: Dictionary = {"value":stored_image(value)}
	return expect(Candidate.fields_match(holder,["value"],{"value":image}) == (expected == {"value":image}),label)

func parity(value: Variant, label: String) -> bool:
	return expect(same_image(Candidate.stored_image(value),stored_image(value)),label) and match_parity(value,stored_image(value),label+" field-match")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = representative_cases()
	passed = lifetime_cases() and passed
	passed = mutation_cases() and passed
	var node: Node = Node.new()
	node.free()
	var cross_types: Array = [[[node],[null]],[[null],[node]],[{"nested":node},{"nested":null}],[{"nested":null},{"nested":node}]]
	for pair in cross_types:
		var holder_case = Holder.new()
		holder_case.value = pair[0]
		var pair_image: Dictionary = {"value":stored_image(pair[1])}
		var pair_original: Dictionary = {"value":stored_image(pair[0])}
		passed = expect(not (pair_original == pair_image),"nested null/freed Object original rejects both directions") and passed
		passed = expect(not Candidate.fields_match(holder_case,["value"],pair_image),"nested null/freed Object matcher rejects both directions") and passed
	var holder = Holder.new()
	holder.value = [1,{"n":2}]
	var image: Dictionary = {"value":stored_image(holder.value)}
	passed = expect(Candidate.fields_match(holder,["value","value"],image),"duplicate field names preserve original dictionary semantics") and passed
	passed = expect(not Candidate.fields_match(holder,["value"],{}),"missing frozen key") and passed
	image["extra"] = 1
	passed = expect(not Candidate.fields_match(holder,["value"],image),"extra frozen key") and passed
	if passed: print("PASS standalone snapshot parity; detached builtins only, not campaign/performance acceptance")
	quit(0 if passed else 1)

func representative_cases() -> bool:
	var node: Node = Node.new()
	var object: Object = Object.new()
	var reference: RefCounted = RefCounted.new()
	var typed_ints: Array[int] = [1,2,3]
	var typed_objects: Array[Node] = [node,null]
	var typed_nested: Array[Array] = [typed_ints,[4,5]]
	var typed_dictionary: Dictionary[String,int] = {"one":1,"two":2}
	var typed_object_dictionary: Dictionary[String,Node] = {"node":node,"null":null}
	var typed_nested_dictionary: Dictionary[String,Array] = {"array":typed_ints}
	var typed_key_dictionary: Dictionary[Object,int] = {}
	typed_key_dictionary[node] = 1
	var readonly_array: Array = [typed_ints,{"n":3}]
	readonly_array.make_read_only()
	var readonly_dictionary: Dictionary = {"array":readonly_array}
	readonly_dictionary.make_read_only()
	var callable: Callable = Callable(node,"get_instance_id")
	var bound: Callable = Callable(self,"echo").bind({"value":[1]})
	var cases: Array = [
		null,false,true,0,-1,9223372036854775807,0.25,-0.0,INF,-INF,NAN,
		"","leaf",&"leaf",NodePath("a/b:c"),RID(),Callable(),callable,bound,Signal(),Signal(node,&"tree_entered"),
		Vector2(1,2),Vector2i(1,2),Rect2(1,2,3,4),Rect2i(1,2,3,4),
		Vector3(1,2,3),Vector3i(1,2,3),Transform2D.IDENTITY,Vector4(1,2,3,4),Vector4i(1,2,3,4),
		Plane(Vector3.UP,2),Quaternion.IDENTITY,AABB(Vector3.ZERO,Vector3.ONE),Basis.IDENTITY,
		Transform3D(Basis.IDENTITY,Vector3.ONE),Projection.IDENTITY,Color(0.25,0.5,0.75,1),
		PackedByteArray([0,127,255]),PackedInt32Array([-2147483648,2147483647]),
		PackedInt64Array([-9007199254740993,9007199254740993]),PackedFloat32Array([0.25,-0.0,INF]),
		PackedFloat64Array([0.25,-0.0,-INF]),PackedStringArray(["","x"]),
		PackedVector2Array([Vector2.ONE]),PackedVector3Array([Vector3.ONE]),
		PackedVector4Array([Vector4.ONE]),PackedColorArray([Color.WHITE]),
		[],{},typed_ints,typed_objects,typed_nested,typed_dictionary,typed_object_dictionary,typed_nested_dictionary,typed_key_dictionary,
		readonly_array,readonly_dictionary,node,object,reference,weakref(node),
		[1,{"deep":[null,NAN,{"leaf":Vector3.ONE,"object":node}]}],
		{"nested":[typed_objects,typed_dictionary],"empty":{},"float_nan":NAN}
	]
	var passed: bool = true
	for index in cases.size():
		passed = parity(cases[index],"representative case "+str(index)) and passed
	var keyed: Dictionary = {}
	keyed[node] = [reference]
	keyed[&"name"] = typed_ints
	var expected: Dictionary = stored_image(keyed)
	var actual: Dictionary = Candidate.stored_image(keyed)
	passed = expect(same_image(actual,expected) and is_same(actual.keys()[0],node),"dictionary keys retain original identity and insertion order") and passed
	passed = expect(actual[node] == [{"object_id":reference.get_instance_id()}],"dictionary values, not keys, become object IDs") and passed
	passed = expect(same_image(NAN,NAN) and not same_image(NAN,0.0) and not same_image(0.0,NAN) and not same_image(1,1.0),"oracle handles NaN and rejects Variant-type changes") and passed
	node.free()
	object.free()
	return passed

func echo(value: Variant) -> Variant:
	return value

func lifetime_cases() -> bool:
	var target: RefCounted = RefCounted.new()
	var target_watch: WeakRef = weakref(target)
	var ref: WeakRef = weakref(target)
	var ref_watch: WeakRef = weakref(ref)
	var ref_id: int = ref.get_instance_id()
	var record: Dictionary = {"ref":ref,"values":[ref_id,Transform3D.IDENTITY]}
	var expected: Dictionary = stored_image(record)
	var frozen: Dictionary = Candidate.stored_image(record)
	var passed: bool = expect(same_image(frozen,expected) and frozen["ref"] == {"object_id":ref_id},"WeakRef's own stored identity")
	target = null
	passed = expect(target_watch.get_ref() == null and ref.get_ref() == null and same_image(Candidate.stored_image(record),frozen) and same_image(stored_image(record),expected),"legitimate weak target retirement leaves prior snapshot stable") and passed
	record["values"][1] = Transform3D(Basis.IDENTITY,Vector3.ONE)
	passed = mutation_detected(record,expected,frozen,"stored weak record data change") and passed
	record.clear()
	ref = null
	passed = expect(ref_watch.get_ref() == null,"neither snapshot retains the WeakRef object") and passed
	var raw: RefCounted = RefCounted.new()
	var raw_watch: WeakRef = weakref(raw)
	var raw_id: int = raw.get_instance_id()
	var raw_record: Dictionary = {"array":[raw],"dictionary":{"ref":raw}}
	var raw_expected: Variant = [stored_image(raw),stored_image(raw_record)]
	var raw_frozen: Variant = [Candidate.stored_image(raw),Candidate.stored_image(raw_record)]
	raw_record.clear()
	raw = null
	passed = expect(raw_watch.get_ref() == null and raw_frozen[0] == {"object_id":raw_id} and same_image(raw_frozen,raw_expected),"raw RefCounted snapshot holds ID without retaining object") and passed
	var node: Node = Node.new()
	var raw_array: Array = [node]
	var raw_dictionary: Dictionary = {"node":node}
	var typed_nodes: Array[Node] = [node]
	var typed_nodes_dictionary: Dictionary[String,Node] = {"node":node}
	var freed_callable: Callable = Callable(node,"get_instance_id")
	node.free()
	passed = parity(freed_callable,"Callable with freed target remains unchanged") and passed
	passed = expect(typeof(node) == TYPE_OBJECT and not is_instance_valid(node),"raw freed Node remains invalid Object Variant") and passed
	passed = parity(node,"freed root Node") and passed
	passed = parity(raw_array,"freed Node in array") and passed
	passed = parity(raw_dictionary,"freed Node in dictionary") and passed
	passed = parity(typed_nodes,"freed Node in typed array") and passed
	passed = parity(typed_nodes_dictionary,"freed Node in typed dictionary") and passed
	passed = expect(Candidate.stored_image(node) == {"object_id":0} and Candidate.stored_image(raw_array) == [{"object_id":0}] and Candidate.stored_image(raw_dictionary) == {"node":{"object_id":0}},"invalid raw Nodes map to zero, not null or stale ID") and passed
	return passed

func mutation_detected(source: Variant, expected: Variant, frozen: Variant, label: String) -> bool:
	var current_expected: Variant = stored_image(source)
	var current_actual: Variant = Candidate.stored_image(source)
	return expect(same_image(current_actual,current_expected) and not same_image(current_expected,expected) and not same_image(current_actual,frozen),label) and match_parity(source,expected,label+" field-match mutation")

func mutation_cases() -> bool:
	var shared: Array = [{"n":1}]
	var aliased: Array = Candidate.stored_image([shared,shared])
	var alias_passed: bool = expect(same_image(aliased,stored_image([shared,shared])) and not is_same(aliased[0],aliased[1]),"repeated container aliases become independent recursive copies")
	var ints: Array[int] = [1,2]
	var packed: PackedInt32Array = PackedInt32Array([1,2])
	var source: Dictionary = {"scalar":1,"nested":[{"count":2},[3]],"typed":ints,"packed":packed,"math":Vector3.ONE}
	var expected: Dictionary = stored_image(source)
	var frozen: Dictionary = Candidate.stored_image(source)
	var passed: bool = expect(same_image(frozen,expected) and not is_same(frozen,source) and not is_same(frozen["nested"],source["nested"]) and not is_same(frozen["nested"][0],source["nested"][0]),"fresh recursive untyped copies") and alias_passed
	source["scalar"] = 2
	passed = mutation_detected(source,expected,frozen,"scalar replacement") and passed
	source["scalar"] = 1
	source["nested"][0]["count"] = 9
	passed = mutation_detected(source,expected,frozen,"deep dictionary value") and passed
	source["nested"][0]["count"] = 2
	source["nested"][1].append(4)
	passed = mutation_detected(source,expected,frozen,"deep array append") and passed
	source["nested"][1].pop_back()
	source["new_key"] = 1
	passed = mutation_detected(source,expected,frozen,"dictionary insertion") and passed
	source.erase("new_key")
	source.erase("math")
	passed = mutation_detected(source,expected,frozen,"dictionary removal") and passed
	source["math"] = Vector3.ONE
	ints[0] = 8
	passed = mutation_detected(source,expected,frozen,"typed array element") and passed
	ints[0] = 1
	source["packed"] = PackedInt32Array([8,2])
	passed = mutation_detected(source,expected,frozen,"packed value replacement") and passed
	source["packed"] = packed
	source["math"] = Vector3.ZERO
	passed = mutation_detected(source,expected,frozen,"math value replacement") and passed
	source["math"] = Vector3.ONE
	passed = expect(same_image(Candidate.stored_image(source),frozen) and same_image(stored_image(source),expected),"restoration restores exact frozen values") and passed
	frozen["nested"][0]["count"] = 99
	passed = expect(source["nested"][0]["count"] == 2 and expected["nested"][0]["count"] == 2,"candidate output mutation cannot reach source or baseline snapshot") and passed
	return passed
