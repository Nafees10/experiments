import std.stdio;
import std.random : uniform;
import std.datetime.stopwatch;
import std.conv : to;
import std.traits;
import std.string;

struct Times{
	ulong min = ulong.max;
	ulong max = 0;
	ulong total = 0;
	ulong avg = 0;
	string toString() const @safe pure{
		return format!"min\tmax\tavg\ttotal\t/msecs\n%d\t%d\t%d\t%d"(
			min, max, avg, total);
	}
}

Times bench(void delegate(ref StopWatch sw) func, ulong runs = 100_000){
	Times time;
	StopWatch sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. runs){
		func(sw);
		immutable ulong currentTime = sw.peek.total!"msecs" - time.total;
		time.min = currentTime < time.min ? currentTime : time.min;
		time.max = currentTime > time.max ? currentTime : time.max;
		time.total = sw.peek.total!"msecs";
	}
	time.avg = time.total / runs;
	return time;
}

void binPrint(size_t num, ubyte bits = size_t.sizeof * 8, char I = '1', char O = '0'){
	foreach (i; 1 .. bits + 1)
		write((num >>> (bits - i)) & 1 ? I : O);
	writeln();
}

size_t mangle(size_t val, size_t key){
	static const bits = size_t.sizeof * 8;
	size_t ret = ~key & val;
	for (ubyte i = 0; i < bits; i ++){
		if ((key >> i) & 1){
			immutable ubyte s1 = i;
			for (i ++; i < bits; i ++){
				if ((key >> i) & 1)
					break;
			}
			if (i == size_t.sizeof * 8){
				ret |= ((val >> s1) & 1) << s1;
				break;
			}
			immutable ubyte s2 = i;
			// magic:
			ret |= (((val >> s2) & 1) << s1) | (((val >> s1) & 1) << s2);
		}
	}
	return ret;
}

size_t mangle(size_t key)(size_t val) pure{
	static size_t rmOdd(size_t key) pure{
		size_t ret;
		for (ubyte i = 0; i < size_t.sizeof * 8; i ++){
			if ((key >> i) & 1){
				immutable ubyte s1 = i;
				for (i ++; i < size_t.sizeof * 8; i ++){
					if ((key >> i) & 1){
						ret |= (1LU << s1) | (1LU << i);
						break;
					}
				}
			}
		}
		return ret;
	}
	static ushort[size_t.sizeof * 4] swapPos(size_t key) pure{
		ushort[size_t.sizeof * 4] ret;
		ubyte count;
		for (ubyte i = 0; i < size_t.sizeof * 8; i ++){
			if ((key >> i) & 1){
				immutable ubyte index = i;
				for (i ++; i < size_t.sizeof * 8; i ++){
					if ((key >> i) & 1){
						ret[count++] = cast(ushort)((i << 8) | index);
						break;
					}
				}
			}
		}
		return ret;
	}
	static const actualKey = rmOdd(key);
	static const ushort[size_t.sizeof * 4] swaps = swapPos(actualKey);
	size_t ret = ~actualKey & val;
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
	Times time;
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
			immutable output = mangle!(key)(j);
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
