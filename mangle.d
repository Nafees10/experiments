import std.stdio;
import std.random : uniform;
import std.datetime.stopwatch;
import std.conv : to;
import std.traits;
void binPrint(ulong num, ubyte bits = 64){
	foreach (i; 1 .. bits + 1)
		write((num >>> (bits - i)) & 1);
	writeln();
}

ulong mangle(ulong val, ulong key){
	ulong ret = ~key & val;
	for (ubyte i = 0; i < 64; i ++){
		if ((key >> i) & 1){
			immutable ubyte s1 = i;
			for (i ++; i < 64; i ++){
				if ((key >> i) & 1)
					break;
			}
			if (i == 64)
				break;
			immutable ubyte s2 = i;
			// magic:
			ret |= (((val >> s2) & 1) << s1) | (((val >> s1) & 1) << s2);
		}
	}
	return ret;
}

T mangle(T, T key)(T val) pure{
	T ret = ~key & val;
	for (ubyte i = 0; i < T.sizeof * 8; i ++){
		if ((key >> i) & 1){
			immutable ubyte s1 = i;
			do{
				i ++;
			}while (!((key >> i) & 1) && i < T.sizeof * 8);
			if (i >= T.sizeof * 8)
				break;
			immutable ubyte s2 = i;
			ret |= (((val >> s2) & 1) << s1) | (((val >> s1) & 1) << s2);
		}
	}
	return ret;
}

T mangleV2(alias key, T)(T val) pure
	if (isNumeric!(typeof(key)) && isNumeric!T){
	static ushort[T.sizeof * 4] swapPos(T key) pure{
		ushort[T.sizeof * 4] ret;
		ubyte count;
		for (ubyte i = 0; i < T.sizeof * 8; i ++){
			if ((key >> i) & 1){
				immutable ubyte index = i;
				for (i ++; i < T.sizeof * 8; i ++){
					if ((key >> i) & 1){
						ret[count++] = cast(ushort)((i << 8) | index);
						break;
					}
				}
			}
		}
		return ret;
	}
	static const ushort[T.sizeof * 4] swaps = swapPos(key);
	T ret = ~key & val;
	static foreach (pos; swaps){
		static if (pos){
			ret |=  (((val >> (pos & ubyte.max)) & 1) << ((pos >> 8) & ubyte.max))|
					(((val >> ((pos >> 8) & ubyte.max)) & 1) << (pos & ubyte.max));
		}
	}
	return ret;
}

void main(string[] args){
	immutable ulong key = 2_294_781_104_715_578_999;
	writefln!"key = %d"(key);
	ulong computations = 1_000_000, runs = 10;
	try{
		if (args.length > 1)
			computations = args[1].to!ulong;
		if (args.length > 2)
			runs = args[2].to!ulong;
	}catch (Exception){
		writeln("crapass input. should be:\n[computations] [runs]");
		return;
	}
	StopWatch sw = StopWatch(AutoStart.no);

	// now its time for fun
	ulong min = ulong.max, max = 0, avg = 0;
	writeln("testing function...");
	foreach (i; 0 .. runs){
		sw.start();
		foreach (j; 0 .. computations)
			immutable output = mangle(j, key);
		sw.stop();
		
		immutable ulong currentTime = sw.peek.total!"msecs" - avg;
		min = currentTime < min ? currentTime : min;
		max = currentTime > max ? currentTime : max;
		avg = sw.peek.total!"msecs";
	}
	avg = sw.peek.total!"msecs" / runs;
	writeln("min\tmax\tavg\ttotal\t/msecs");
	writefln!"%d\t%d\t%d\t%d"(min, max, avg, sw.peek.total!"msecs");

	sw.reset();
	min = ulong.max, max = 0, avg = 0;
	writeln("testing template...");
	foreach (i; 0 .. runs){
		sw.start();
		foreach (j; 0 .. computations)
			immutable output = mangleV2!(key)(j);
		sw.stop();
		
		immutable ulong currentTime = sw.peek.total!"msecs" - avg;
		min = currentTime < min ? currentTime : min;
		max = currentTime > max ? currentTime : max;
		avg = sw.peek.total!"msecs";
	}
	avg = sw.peek.total!"msecs" / runs;
	writeln("min\tmax\tavg\ttotal\t/msecs");
	writefln!"%d\t%d\t%d\t%d"(min, max, avg, sw.peek.total!"msecs");
}
