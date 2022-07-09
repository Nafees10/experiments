import std.stdio;
import std.random : uniform;
import std.datetime.stopwatch;
import std.conv : to;
import std.algorithm;
import std.functional;
import std.traits;
import std.string;
import std.parallelism;

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

Times bench(void delegate() func, ulong runs = 100_000){
	Times time;
	StopWatch sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. runs){
		sw.start();
		func();
		sw.stop();
		immutable ulong currentTime = sw.peek.total!"msecs" - time.total;
		time.min = currentTime < time.min ? currentTime : time.min;
		time.max = currentTime > time.max ? currentTime : time.max;
		time.total = sw.peek.total!"msecs";
	}
	time.avg = time.total / runs;
	return time;
}

void main(string[] args){
	ulong N = 1_000_000, X = 10_000, runs = 1_000;
	try{
		if (args.length > 1)
			N = args[1].to!ulong;
		if (args.length > 2)
			X = args[2].to!ulong;
		if (args.length > 3)
			runs = args[3].to!ulong;
	}catch (Exception){
		writeln("args should be:\n[N] [X] [runs]");
		return;
	}

	Times time;
	ulong[] list = getRand(N);
	ulong[] output;
	// run few times, in case conservative cpu governor
	foreach (i; 0 .. 10)
		output = partialSort(list, X);

	output = list.dup;
	time = bench((ref StopWatch sw){
		sw.start();
		output = radixSort(output);
		sw.stop();
		output[] = list;
	}, runs);
	writefln!"executed radixSort, %d times:\n%s"(runs, time);

	output = list.dup;
	time = bench((ref StopWatch sw){
		sw.start();
		output = radixSortParallel(output);
		sw.stop();
		output[] = list;
	}, runs);
	writefln!"executed radixSortParallel, %d times:\n%s"(runs, time);

	time = bench((){
		output = partialSort(list, X);
	}, runs);
	writefln!"executed partialSort, %d times:\n%s"(runs, time);

	assert (isSorted(radixSort(list)));
	assert (isSorted(radixSortParallel(list)));
}

ulong[] getRand(ulong size){
	ulong[] ret;
	ret.length = size;
	foreach (i; 0 .. size)
		ret[i] = uniform(0, ulong.max);
	return ret;
}

T[] partialSort(alias val = "a", T)(T[] input, ulong count){
	T[] selection = radixSort!val(input[0 .. count]);
	T[] temp;
	temp.length = count;
	T cmp = selection[$ - 1];

	input = input[count .. $];
	ulong i;
	foreach (num; input){
		if (num < cmp){
			temp[i ++] = num;
			if (i == temp.length){
				selection = mergeEq!val(selection, radixSort!val(temp));
				i = 0;
				cmp = selection[$ - 1];
			}
		}
	}
	if (i)
		selection = merge!val(selection, radixSort!val(temp[0 .. i]), count);
	return selection;
}

T[] radixSort(alias val = "a", T)(T[] input){
	alias valGet = unaryFun!val;
	static immutable ubyte end = T.sizeof * 8;
	size_t[256] counts;
	T[] output = new T[input.length];
	for (ubyte i = 0; i < end; i += 8){
		counts[] = 0;
		foreach (val; input)
			++ counts[(valGet(val) >> i) & 255];
		foreach (j; 1 .. counts.length)
			counts[j] += counts[j - 1];
		foreach_reverse (val; input)
			output[-- counts[(valGet(val) >> i) & 255]] = val;
		swap(input, output);
	}
	return input;
}

/// Merge 2 sorted arrays of same length. discard second half
T[] mergeEq(alias val = "a", T)(T[] A, T[] B){
	alias valGet = unaryFun!val;
	T[] R;
	R.length = A.length;
	for (size_t i, a, b; i < R.length; i ++)
		R[i] = valGet(A[a]) < valGet(B[b]) ? A[a ++] : B[b ++];
	return R;
}

/// Merge 2 sorted arrays
T[] merge(alias val = "a", T)(T[] A, T[] B, ulong maxLen = 0){
	alias valGet = unaryFun!val;
	T[] R;
	R.length = maxLen && maxLen < A.length + B.length ? maxLen : A.length + B.length;

	ulong a, b, i;
	if (A.length && B.length){
		while (i < R.length){
			if (valGet(A[a]) < valGet(B[b])){
				R[i ++] = A[a ++];
				if (a == A.length)
					break;
			}else{
				R[i ++] = B[b ++];
				if (b == B.length)
					break;
			}
		}
	}
	if (a < A.length){
		R[i .. $] = A[a .. a + R.length - i];
	}else if (b < B.length){
		R[i .. $] = B[b .. b + R.length - i];
	}
	return R;
}
