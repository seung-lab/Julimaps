module Bucket

using ...Julitasks.Types

export download, upload

"""
    download(bucket::BucketService, remote_file::ASCIIString,
local_file::Union{ASCIIString, IO})

Download a remote file either to a new location `ASCIIString` or a stream `IO`.
"""
function download(bucket::BucketService, remote_file::ASCIIString,
    local_file::Union{ASCIIString, IO})
    error("download with $bucket is not implemented")
end

"""
    upload(bucket::BucketService, local_file::Union{ASCIIString, IO},
remote_file::ASCIIString)

Upload a file `ASCIIString` or a stream `IO` to the bucket service.
"""
function upload(bucket::BucketService, local_file::Union{ASCIIString, IO},
    remote_file::ASCIIString)
    error("upload with $bucket is not implemented")
end

end # module Bucket
