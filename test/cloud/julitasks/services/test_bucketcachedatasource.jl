module TestDatasource

using Base.Test
using CloudTest.JulitasksTests.Utils.MockServices
using Julimaps.Cloud.Julitasks.Services.BucketCacheDatasource

import Julimaps.Cloud.Julitasks.Services.Bucket
import Julimaps.Cloud.Julitasks.Services.Cache
import Julimaps.Cloud.Julitasks.Services.Datasource

function test_get_empty_cache()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_values = Dict()

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)

    datasource = BucketCacheDatasourceService(bucket, cache)

    Datasource.get(datasource, key)

    @test haskey(cache.mockValues, key)
    new_cache_value = cache.mockValues[key]
    # cache gets updated with the bucket text
    @test readchomp(new_cache_value) == bucket_text 
end

function test_get_multi_empty_cache()
    key = "somekey"
    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)

    key2 = "somekey2"
    bucket_text2 = "mock contents2"
    bucket_file2 = IOBuffer(bucket_text2)
    seekstart(bucket_file2)

    bucket_files = Dict()
    bucket_files[key] = bucket_file
    bucket_files[key2] = bucket_file2

    cache_values = Dict()

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)

    datasource = BucketCacheDatasourceService(bucket, cache)

    Datasource.get(datasource, [key, key2])

    @test haskey(cache.mockValues, key)
    new_cache_value = cache.mockValues[key]
    # cache gets updated with the bucket text
    @test readchomp(new_cache_value) == bucket_text

    @test haskey(cache.mockValues, key2)
    new_cache_value2 = cache.mockValues[key2]
    # cache gets updated with the bucket text
    @test readchomp(new_cache_value2) == bucket_text2
end

function test_get_with_cache()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_text = "mock contents cached already"
    cache_io = IOBuffer(cache_text)
    seekstart(cache_io)
    cache_values = Dict()
    cache_values[key] = cache_io

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)
    datasource = BucketCacheDatasourceService(bucket, cache)

    Datasource.get(datasource, key)

    @test haskey(cache.mockValues, key)
    new_cache_io = cache.mockValues[key]
    # cache does not get updated because it is already in there
    @test readchomp(new_cache_io) == cache_text
end

function test_get_no_bucket()
    key = "somekey"

    bucket_files = Dict()
    cache_values = Dict()

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)
    datasource = BucketCacheDatasourceService(bucket, cache)

    @test_throws Exception Datasource.get(datasource, key)
end

function test_force_get_empty_cache()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_values = Dict()

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)

    datasource = BucketCacheDatasourceService(bucket, cache)

    Datasource.get(datasource, key; force=true)

    @test haskey(cache.mockValues, key)
    new_cache_value = cache.mockValues[key]
    # cache gets forced to update with the new bucket text
    @test readchomp(new_cache_value) == bucket_text 
end

function test_force_get_with_cache()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_text = "mock contents cached already"
    cache_io = IOBuffer(cache_text)
    seekstart(cache_io)
    cache_values = Dict()
    cache_values[key] = cache_io

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)
    datasource = BucketCacheDatasourceService(bucket, cache)

    Datasource.get(datasource, key; force=true)

    @test haskey(cache.mockValues, key)
    new_cache_io = cache.mockValues[key]
    # cache gets forced to update with the new bucket text
    @test readchomp(new_cache_io) == bucket_text
end

function test_put()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_text = "mock contents cached already"
    cache_io = IOBuffer(cache_text)
    seekstart(cache_io)
    cache_values = Dict()
    cache_values[key] = cache_io

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)
    datasource = BucketCacheDatasourceService(bucket, cache)

    result = Datasource.put!(datasource, key)

    @test result == true

    @test haskey(bucket.mockFiles, key)
    bucket_file = bucket.mockFiles[key]
    # puting back to bucket with new cached file updates bucket
    @test readchomp(bucket_file) == cache_text
end

function test_put_multi()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_text = "mock contents cached already"
    cache_io = IOBuffer(cache_text)
    seekstart(cache_io)
    cache_values = Dict()
    cache_values[key] = cache_io

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)
    datasource = BucketCacheDatasourceService(bucket, cache)

    result = Datasource.put!(datasource, key)

    @test result == true

    @test haskey(bucket.mockFiles, key)
    bucket_file = bucket.mockFiles[key]
    # puting back to bucket with new cached file updates bucket
    @test readchomp(bucket_file) == cache_text
end

function test_put_not_exist()
    key = "somekey"

    bucket_text = "mock contents"
    bucket_file = IOBuffer(bucket_text)
    seekstart(bucket_file)
    bucket_files = Dict()
    bucket_files[key] = bucket_file

    cache_values = Dict()

    bucket = MockBucketService(bucket_files)
    cache = MockCacheService(cache_values)
    datasource = BucketCacheDatasourceService(bucket, cache)

    result = Datasource.put!(datasource, key)

    @test result == false

    @test haskey(bucket.mockFiles, key)
    bucket_file = bucket.mockFiles[key]
    # puting back to bucket when not existing in cache does not modify bucket
    @test readchomp(bucket_file) == bucket_text
end

function __init__()
    test_get_empty_cache()
    test_get_multi_empty_cache()
    test_get_with_cache()
    test_get_no_bucket()
    test_force_get_empty_cache()
    test_force_get_with_cache()

    test_put()
    test_put_multi()
    test_put_not_exist()
end

end # module TestDatasource
