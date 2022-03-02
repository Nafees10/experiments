import std.stdio;
import std.datetime.stopwatch;
import std.random;

abstract class ListBase(T, ubyte LENBIT){
private:
	T[1 << LENBIT] _list;
public:
	this(){
		assert (LENBIT <= 16, "ListBase constructed with LENBIT > 16");
	}
	abstract void put(uint index, T data);
	abstract T get(uint index);
	// true if corrupt
	abstract @property bool boundCheck();
}

class ListNew(T, ubyte LENBIT = 4) : ListBase!(T, LENBIT){
private:
	uint _history;
public:
	/// constructor
	this(){
		_history = 0;
	}
	override void put(uint index, T data){
		_history |= index;
		_list[index & ((1 << LENBIT) - 1)] = data;
	}
	override T get(uint index){
		_history |= index;
		return _list[index & ((1 << LENBIT) - 1)];
	}
	override @property bool boundCheck(){
		immutable bool ret = (_history >> LENBIT) > 0;
		_history = 0;
		return ret;
	}
}

class ListOld(T, ubyte LENBIT = 4) : ListBase!(T, LENBIT){
private:
	bool _boundsExceeded = false;
public:
	override void put(uint index, T data){
		if (index < _list.length)
			_list[index] = data;
		else
			_boundsExceeded = true;
	}
	override T get(uint index){
		if (index < _list.length)
			return _list[index];
		_boundsExceeded = true;
		return _list[0];
	}
	override @property bool boundCheck(){
	immutable bool ret = _boundsExceeded;
	_boundsExceeded = false;
		return _ret;
	}
}

uint[] getIndexes(ubyte lenBit, uint count, uint badCount){
	assert (lenBit <= 16);
	uint[] ret;
	ret.length = count;
	foreach (i; 0 .. count){
		immutable ushort rnd = cast(ushort)uniform(0, 1 << lenBit);
		if (badCount && (badCount >= (count - i) || uniform(0, 2))){
			ret[i] = (rnd << lenBit) + rnd;
			badCount --;
		}else
			ret[i] = rnd;
	}
	return ret;
}

uint[] getVals(uint count){
	uint[] ret;
	ret.length = count;
	foreach (i; 0 .. count)
		ret[i] = uniform(0, uint.max);
	return ret;
}

/// [bitwise [write, read, errors], range [write, read, errors]]
uint[3][2] test(bool quiet = false)(uint totalCases, uint badCases, uint repetition){
	assert (badCases <= totalCases, "test called with badCases > totalCases");
	const ubyte BIT = 16;
	if (!quiet){
		writeln ("testing with ", badCases, "/", totalCases, " bad cases, ", repetition,
			" repetitions");
		writeln("\tWrite\tRead\tErrors\tboundCheck");
	}
	StopWatch sw = StopWatch(AutoStart.no);
	uint[3][2] ret = [[0,0,0],[0,0,0]];
	uint[] indexes = getIndexes(BIT, totalCases, badCases), vals = getVals(totalCases);
	uint errors = 0;
	auto n = new ListNew!(uint, BIT);
	sw.start();
	foreach (rep; 0 .. repetition){
		foreach (i; 0 .. totalCases)
			n.put(indexes[i], vals[i]);
	}
	sw.stop();
	ret[0][0] = cast(uint)sw.peek.total!"msecs";
	sw.reset();
	sw.start();
	foreach (rep; 0 .. repetition){
		foreach (i; 0 .. totalCases)
			errors += n.get(indexes[i]) != vals[i];
	}
	sw.stop();
	ret[0][1] = cast(uint)sw.peek.total!"msecs";
	ret[0][2] = errors / repetition;
	if (!quiet){
		writeln("bitwise\t",ret[0][0],"\t",ret[0][1],"\t",ret[0][2],"\t",n.boundCheck());
	}

	errors = 0;
	sw.reset();
	.destroy (n);
	auto o = new ListOld!(uint, BIT);sw.start();
	foreach (rep; 0 .. repetition){
		foreach (i; 0 .. totalCases)
			o.put(indexes[i], vals[i]);
	}
	sw.stop();
	ret[1][0] = cast(uint)sw.peek.total!"msecs";
	sw.reset();
	sw.start();
	foreach (rep; 0 .. repetition){
		foreach (i; 0 .. totalCases)
			errors += o.get(indexes[i]) != vals[i];
	}
	sw.stop();
	ret[1][1] = cast(uint)sw.peek.total!"msecs";
	ret[1][2] = errors / repetition;
	if (!quiet){
		writeln("range\t",ret[1][0],"\t",ret[1][1],"\t",ret[1][2],"\t",o.boundCheck());
	}
	.destroy (o);
	return ret;
}

void main(){
	const uint CASES = 10_000, REPETITION = 2_000;
	// warmp up
	test!true(CASES, 0, REPETITION);
	foreach (i; 0 .. 10){
		immutable uint badCount = i * CASES / 10;
		test(CASES, badCount, REPETITION);
	}
}
