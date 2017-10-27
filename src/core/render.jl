"""
Multiple dispatch for meshwarp on Mesh object
"""
function meshwarp_mesh(mesh::Mesh)
  img = get_image(mesh)
  src_nodes = get_nodes(mesh; globalized = true, use_post = false)
  dst_nodes = get_nodes(mesh; globalized = true, use_post = true)
  offset = get_offset(mesh);
  #=print("incidence_to_dict: ")
  @time node_dict = incidence_to_dict(mesh.edges') #'
  print("dict_to_triangles: ")
  @time triangles = dict_to_triangles(node_dict)=#
  return @time meshwarp(img, src_nodes, dst_nodes, incidence_to_triangles(mesh.edges), offset), get_index(mesh)
end

"""
Reverts transform that went from index and returns the image at the index
"""
function meshwarp_revert(index::FourTupleIndex, img = get_image(nextstage(index)), interp = false)
  mesh = load("Mesh", index)
  src_nodes = get_nodes(mesh; use_post = false)
  dst_nodes = get_nodes(mesh; use_post = true)
  offset = get_offset(nextstage(index));
  #=print("incidence_to_dict: ")
  @time node_dict = incidence_to_dict(mesh.edges') #'
  print("dict_to_triangles: ")
  @time triangles = dict_to_triangles(node_dict)=#
  @time reverted_img, reverted_offset = meshwarp(img, dst_nodes, src_nodes, incident_to_triangles(mesh.edges), offset, interp)
  original_image_size = get_image_size(index)
  original_offset = get_offset(index)
  i_range = (1:original_image_size[1]) - reverted_offset[1] + original_offset[1] 
  j_range = (1:original_image_size[2]) - reverted_offset[2] + original_offset[2] 
  @inbounds return reverted_img[i_range, j_range]
end

"""
One-off code for CREMI
"""
function segmentation_revert(fn, savepath)
	segs = h5read(fn, "main")
	#cutout_range_i = 401:2900
	#cutout_range_j = 201:2700
	cutout_range_i = 651:2650
	cutout_range_j = 451:2450

	segs_reverted = zeros(UInt32, 1250, 1250, 125)
	for i in 1:125
	  	sec_num = i + 37
		img = zeros(UInt32, get_image_size(aligned(1,sec_num))...)
		offset = get_offset(aligned(1,sec_num))
		img[cutout_range_i - offset[1] + 1, cutout_range_j - offset[2] + 1] = segs[:,:,i]
		img_reverted = meshwarp_revert(prealigned(1,sec_num), img)
		segs_reverted[:,:,i] = img_reverted[912:2161, 912:2161]
	end
		f = h5open(savepath, "w"); @time f["main"] = segs_reverted; 
		close(f)
	return segs_reverted

end

"""
`MERGE_IMAGES` - Place images in global reference image

    merged_img, 2D_slice = merge_images(imgs, offsets)

* `imgs`: 1D array, images (2D arrays)
* `offsets`: 1D array, 2-element array positions of corresponding image 
  in 'imgs` in global space

""" 
function merge_images{T}(imgs::Array{Array{T,2},1}, offsets)
    # T = typeof(imgs[1][1])
    bbs = []
    for (img, offset) in zip(imgs, offsets)
        push!(bbs, ImageRegistration.BoundingBox(offset..., size(img)...))
    end
    global_ref = sum(bbs)
    merged_img = zeros(T, global_ref.h, global_ref.w)
    no_imgs = length(imgs)
    for (idx, (img, bb)) in enumerate(zip(imgs, bbs))
        println("Merging image # ", idx , " / ", no_imgs)
        i = bb.i - global_ref.i+1
        j = bb.j - global_ref.j+1
        w = bb.w-1
        h = bb.h-1
        merged_img[i:i+h, j:j+w] = max.(merged_img[i:i+h, j:j+w], img)
        imgs[idx] = typeof(img)(0,0)
    end
    return merged_img, bb_to_slice(global_ref)
end

"""
Rescope image from one bounding box to another
"""
function rescope{T}(img::Array{T}, src_slice, dst_slice)
    src_bb = ImageRegistration.slice_to_bb(src_slice)
    dst_bb = ImageRegistration.slice_to_bb(dst_slice)
    src_offset = ImageRegistration.get_offset(src_bb)
    dst_offset = ImageRegistration.get_offset(dst_bb)
    dst = zeros(T, dst_bb.h, dst_bb.w)
    if intersects(src_bb, dst_bb)
        src_roi = translate_bb(dst_bb-src_bb, -src_offset+[1,1])
        dst_roi = translate_bb(dst_bb-src_bb, -dst_offset+[1,1])
        dst[bb_to_slice(dst_roi)...] = img[bb_to_slice(src_roi)...]
    end
    return dst
end


@fastmath @inbounds function render(ms::MeshSet, mesh_indices=collect_z(ms))
  sort!(ms.meshes; by=get_index)
  for z in collect_z(ms)
    if z in mesh_indices
      meshes = get_subsections(ms, z)
      subsection_imgs = Array{Array{UInt8,2},1}()
      subsection_offsets = []
      for mesh in meshes
        index = get_index(mesh)
        println("Warping ", index)
        @time (img, offset), _ = meshwarp_mesh(mesh)
        push!(subsection_imgs, img)
        push!(subsection_offsets, offset)
      end
      img, slice = merge_images(subsection_imgs, subsection_offsets)
      slice = tuple(slice..., z:z)
      save_image(z, "dst_image", img, slice)
    end
  end
end