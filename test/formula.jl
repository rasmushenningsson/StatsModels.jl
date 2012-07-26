# TODO:
# - grouped variables in formulas with interactions
# - is it fast?  Can expand() handle DataFrames?
# - deal with intercepts
# - implement ^2 for datavecs
# - support more transformations with I()?

# Load files
load("src/init.jl")

# test_group("Formula")

d = DataFrame()
d["y"] = [1:4]
d["x1"] = PooledDataVec([5:8])
d["x2"] = [9:12]
d["x3"] = [11:14]
f = Formula(:(y ~ x1 * (log(x2) + x3)))
mf = model_frame(f, d)
mm = model_matrix(mf)
@assert mm.model_colnames == [
 "(Intercept)"
 "x1:6"        
 "x1:7"        
 "x1:8"        
 "log(x2)"     
 "x3"          
 "x1:6&log(x2)"
 "x1:6&x3"     
 "x1:7&log(x2)"
 "x1:7&x3"     
 "x1:8&log(x2)"
 "x1:8&x3" ]

tmp = d["x2"]
 
# # test_group("Basic tests")

d = DataFrame()
d["y"] = [1:4]
d["x1"] = [5:8]
d["x2"] = [9:12]

x1 = [5.:8]
x2 = [9.:12]
f = Formula(:(y ~ x1 + x2))
mf = model_frame(f, d)
mm = model_matrix(mf)
@assert mm.response_colnames == ["y"]
@assert mm.model_colnames == ["(Intercept)","x1","x2"]
@assert mm.response == [1. 2 3 4]'
@assert mm.model[:,1] == ones(4)
@assert mm.model[:,2:3] == [x1 x2]

# test_group("expanding a PooledVec into a design matrix of indicators for each dummy variable")

a = expand(PooledDataVec(x1), "x1")
@assert a[:,1] == DataVec([0, 1., 0, 0])
@assert a[:,2] == DataVec([0, 0, 1., 0])
@assert a[:,3] == DataVec([0, 0, 0, 1.])
@assert colnames(a) == ["x1:6.0", "x1:7.0", "x1:8.0"]

# test_group("create a design matrix from interactions from two DataFrames")

b = DataFrame()
b["x2"] = DataVec(x2)
df = interaction_design_matrix(a,b)
@assert df[:,1] == DataVec([0, 10., 0, 0])
@assert df[:,2] == DataVec([0, 0, 11., 0])
@assert df[:,3] == DataVec([0, 0, 0, 12.])

# test_group("expanding an singleton expression/symbol into a DataFrame")

df = copy(d)
ex = :(x2)
r = expand_helper(ex, df)
@assert isa(r, DataFrame)
@assert r[:,1] == DataVec([9,10,11,12])

df = copy(d)
ex = :(log(x2))
r = expand_helper(ex, df)
@assert isa(r, DataFrame)
@assert r[:,1] == DataVec(log([9,10,11,12]))

ex = :(x1 & x2)
r = expand(ex, df)
@assert isa(r, DataFrame)
@assert ncol(r) == 1
@assert r[:,1] == DataVec([45, 60, 77, 96])

r = expand(:(x1 + x2), df)
@assert isa(r, DataFrame)
@assert ncol(r) == 2
@assert r[:,1] == DataVec(df["x1"])
@assert r[:,2] == DataVec(df["x2"])

df["x1"] = PooledDataVec(x1)
r = expand_helper(:(x1), df)
@assert isa(r, DataFrame)
@assert ncol(r) == 3
@assert r == expand(PooledDataVec(x1),"x1")

r = expand(:(x1 + x2), df)
@assert isa(r, DataFrame)
@assert ncol(r) == 4
@assert r[:,1:3] == expand(PooledDataVec(x1),"x1")
@assert r[:,4] == DataVec(df["x2"])

df["x2"] = PooledDataVec(x2)
r = expand(:(x1 + x2), df)
@assert isa(r, DataFrame)
@assert ncol(r) == 6
@assert r[:,1:3] == expand(PooledDataVec(x1),"x1")
@assert r[:,4:6] == expand(PooledDataVec(x2),"x2")

# test_group("Creating a model matrix using full formulas: y ~ x1 + x2, etc")

df = copy(d)
f = Formula(:(y ~ x1 & x2))
mf = model_frame(f, df)
mm = model_matrix(mf)
@assert mm.model == [ones(4) x1.*x2]

f = Formula(:(y ~ x1 * x2))
mf = model_frame(f, df)
mm = model_matrix(mf)
@assert mm.model == [ones(4) x1 x2 x1.*x2]

df["x1"] = PooledDataVec(x1)
x1e = [[0, 1, 0, 0] [0, 0, 1, 0] [0, 0, 0, 1]]
f = Formula(:(y ~ x1 * x2))
mf = model_frame(f, df)
mm = model_matrix(mf)
@assert mm.model == [ones(4) x1e x2 [0, 10, 0, 0] [0, 0, 11, 0] [0, 0, 0, 12]]

# test_group("Basic transformations")

df = copy(d)
f = Formula(:(y ~ x1 + log(x2)))
mf = model_frame(f, df)
mm = model_matrix(mf)
@assert mm.model == [ones(4) x1 log(x2)]

d = DataFrame()
d["y"] = [1:4]
d["x1"] = PooledDataVec([5:8])
d["x2"] = [9:12]
d["x3"] = [11:14]
f = Formula(:(y ~ x1 * (log(x2) + x3)))
mf = model_frame(f, d)
mm = model_matrix(mf)
@assert mm.model_colnames == [
 "(Intercept)"
 "x1:6"        
 "x1:7"        
 "x1:8"        
 "log(x2)"     
 "x3"          
 "x1:6&log(x2)"
 "x1:6&x3"     
 "x1:7&log(x2)"
 "x1:7&x3"     
 "x1:8&log(x2)"
 "x1:8&x3" ]

# test_group("Model frame response variables")

f = Formula(:(x1 + x2 ~ y + x3))
mf = model_frame(f, d)
@assert mf.y_indexes == [1, 2]
@assert isequal(mf.formula.lhs, [:(x1 + x2)])
@assert isequal(mf.formula.rhs, [:(y + x3)])

## test_group("Include all terms")

## f = Formula(:(y ~ .))
## mm = model_matrix(model_frame(f,d))
## @assert mm.model == [ones(4) x1 x2]


## test_group("Do not include same term twice")

## f = Formula(:(y ~ x1 + x1))
## mm = model_matrix(model_frame(f,d))
## @assert error?

## test_group("Intercept options")

## f = Formula(:(y ~ 1))
## mm = model_matrix(model_frame(f,d))
## @assert mm.model == [ones(4)]

## f = Formula(:(y ~ x1 + 0))
## mm = model_matrix(model_frame(f,d))
## @assert mm.model == x1

## f = Formula(:(y ~ x1 - 1))
## mm = model_matrix(model_frame(f,d))
## @assert mm.model == x1

## f = Formula(:(y ~ x1 + x2 - 1))
## mm = model_matrix(model_frame(f,d))
## @assert mm.model == [x1 x2]

## f = Formula(:(y ~ . - 1))
## mm = model_matrix(model_frame(f,d))
## @assert mm.model == [x1 x2]

## # Should throw errors since there the model would be empty
## f = Formula(:(y ~ - 1))
## mm = model_matrix(model_frame(f,d))
## @assert error

## # Should throw errors since there the model would be empty
## f = Formula(:(y ~ 0))
## mm = model_matrix(model_frame(f,d))
## @assert error
