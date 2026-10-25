extends RefCounted

## Immutable Foundry revision-one terrain; never reconstruct it from revision zero.
const FOUNDRY = {
	"cell_size": 4,
	"rects": [
		[
			12,
			28,
			17,
			32
		],
		[
			16,
			24,
			17,
			28
		],
		[
			12,
			24,
			17,
			25
		],
		[
			12,
			19,
			13,
			25
		],
		[
			10,
			17,
			18,
			22
		],
		[
			5,
			19,
			12,
			20
		],
		[
			3,
			10,
			10,
			18
		],
		[
			8,
			7,
			9,
			10
		],
		[
			8,
			6,
			25,
			7
		],
		[
			16,
			7,
			17,
			17
		],
		[
			21,
			8,
			28,
			14
		],
		[
			23,
			7,
			24,
			8
		],
		[
			23,
			15,
			24,
			23
		],
		[
			18,
			22,
			24,
			23
		],
		[
			12,
			3,
			13,
			6
		],
		[
			9,
			0,
			16,
			3
		],
		[
			1,
			13,
			3,
			14
		]
	],
	"elevations": [
		{
			"rect": [
				11,
				3,
				15,
				6
			],
			"height": 1.0
		},
		{
			"rect": [
				0,
				-10,
				10,
				60
			],
			"height": 0
		},
		{
			"rect": [
				10,
				-10,
				14,
				60
			],
			"axis": 0,
			"start": 10.0,
			"end": 14,
			"height": 2
		},
		{
			"rect": [
				14,
				-10,
				18,
				60
			],
			"height": 2
		},
		{
			"rect": [
				18,
				-10,
				22,
				60
			],
			"axis": 0,
			"start": 14.0,
			"end": 22,
			"height": 4
		},
		{
			"rect": [
				22,
				-10,
				50,
				60
			],
			"height": 4
		}
	],
	"ceilings": [
		{
			"rect": [
				3,
				10,
				10,
				18
			],
			"height": 10
		},
		{
			"rect": [
				21,
				8,
				28,
				14
			],
			"height": 8
		}
	],
	"floor_revision": 1
}

## Immutable Intake revision-one terrain, used only to validate/migrate old saves.
const INTAKE = {
	"cell_size": 4,
	"rects": [
		[
			11,
			26,
			17,
			30
		],
		[
			11,
			20,
			17,
			25
		],
		[
			5,
			23,
			11,
			24
		],
		[
			5,
			19,
			6,
			23
		],
		[
			2,
			12,
			9,
			18
		],
		[
			5,
			7,
			6,
			12
		],
		[
			4,
			7,
			12,
			9
		],
		[
			13,
			7,
			14,
			10
		],
		[
			11,
			10,
			17,
			19
		],
		[
			17,
			22,
			23,
			23
		],
		[
			22,
			18,
			23,
			23
		],
		[
			20,
			11,
			26,
			18
		],
		[
			23,
			9,
			24,
			11
		],
		[
			17,
			7,
			24,
			9
		],
		[
			13,
			5,
			14,
			9
		],
		[
			10,
			0,
			18,
			4
		],
		[
			1,
			15,
			2,
			16
		]
	],
	"elevations": [
		{
			"rect": [
				10,
				7,
				17,
				10
			],
			"axis": 0,
			"start": 10,
			"end": 14,
			"height": 1.5
		},
		{
			"rect": [
				10,
				10,
				14,
				13
			],
			"axis": 0,
			"start": 10,
			"end": 14,
			"height": 1.5
		},
		{
			"rect": [
				17,
				7,
				30,
				10
			],
			"axis": 0,
			"start": 11,
			"end": 23,
			"height": 3
		},
		{
			"rect": [
				20,
				10,
				30,
				18
			],
			"height": 3
		},
		{
			"rect": [
				20,
				18,
				30,
				31
			],
			"axis": 1,
			"start": 24,
			"end": 18,
			"height": 3
		},
		{
			"rect": [
				11,
				19,
				18,
				26
			],
			"axis": 1,
			"start": 25,
			"end": 19,
			"height": 1.5
		},
		{
			"rect": [
				11,
				10,
				18,
				19
			],
			"height": 1.5
		},
		{
			"rect": [
				13,
				4,
				15,
				7
			],
			"axis": 1,
			"start": 4,
			"end": 7,
			"height": 1.5
		}
	],
	"ceilings": [
		{
			"rect": [
				13,
				10,
				15,
				30
			],
			"height": 26
		},
		{
			"rect": [
				11,
				10,
				17,
				30
			],
			"height": 14
		},
		{
			"rect": [
				0,
				12,
				9,
				18
			],
			"height": 10
		}
	],
	"floor_revision": 1
}
