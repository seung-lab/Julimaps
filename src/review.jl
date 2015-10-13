"""
Remove matches from meshset corresponding to the indices provided.

Args:

* indices_to_remove: array of indices of match points to remove
* match_index: the index of the matches object in the meshset
* meshset: the meshset containing all the matches

Returns:

* (updated meshset)

  remove_matches_from_meshset!(indices_to_remove, match_index, meshset)
"""
function remove_matches_from_meshset!(indices_to_remove, match_index, meshset)
  println("Removing ", length(indices_to_remove), " points")
  if length(indices_to_remove) > 0
    no_pts_removed = length(indices_to_remove)
    matches = meshset.matches[match_index]
    flag = trues(matches.n)
    flag[indices_to_remove] = false
    matches.src_points_indices = matches.src_points_indices[flag]
    matches.n -= no_pts_removed
    matches.dst_points = matches.dst_points[flag]
    if is_aligned(meshset.meshes[1].index)
      matches.dst_triangles = matches.dst_triangles[flag]
      matches.dst_weights = matches.dst_weights[flag]
      matches.disp_vectors = matches.disp_vectors[flag]
      meshset.m -= no_pts_removed
      meshset.m_e -= no_pts_removed
    else
      dst_mesh = meshset.meshes[2]
      dst_mesh.nodes = dst_mesh.nodes[flag]
      dst_mesh.n -= no_pts_removed
    end
  end
end

function remove_matches_from_prealigned_meshset!(indices_to_remove, meshset)
  println("Removing ", length(indices_to_remove), " points")
  if length(indices_to_remove) > 0
    no_pts_removed = length(indices_to_remove)
    matches = meshset.matches[1]
    flag = trues(matches.n)
    flag[indices_to_remove] = false
    matches.src_points_indices = matches.src_points_indices[flag]
    matches.n -= no_pts_removed
    matches.dst_points = matches.dst_points[flag]
  end
end

"""
Find index of location in array with point closest to the given point (if there
exists such a unique point within a certain pixel limit).

Args:

* pts: 2xN array of coordinates
* pt: 2-element coordinate array of point in interest
* limit: number of pixels that nearest must be within

Returns:

* index of the nearest point in the pts array

  idx = find_idx_of_nearest_pt(pts, pt, limit)
"""
function find_idx_of_nearest_pt(pts, pt, limit)
    d = sum((pts.-pt).^2, 1).^(1/2)
    idx = eachindex(d)'[d .< limit]
    if length(idx) == 1
        return idx[1]
    else
        return 0
    end
end

"""
Provide bindings for GUI to right-click and remove matches from a mesh. End 
manual removal by exiting the image window, or by pressing enter while focused
on the image window.

Args:

* imgc: ImageCanvas object (from image with annotations)
* img2: ImageZoom object (from image with annotations)
* annotation: the annotation object from the image

Returns:

* pts_to_remove: array of indices for points to remove from mesh

  pts_to_remove = edit_matches(imgc, img2, annotation)
"""
function edit_matches(imgc, img2, annotation)
    e = Condition()

    pts_to_remove = Array{Integer,1}()
    pts = copy(annotation.ann.data.pts)

    c = canvas(imgc)
    win = Tk.toplevel(c)
    bind(c, "<Button-3>", (c, x, y)->right_click(parse(Int, x), parse(Int, y)))
    bind(win, "<Destroy>", path->end_edit())

    function right_click(x, y)
        xu,yu = Graphics.device_to_user(Graphics.getgc(imgc.c), x, y)
        xi, yi = floor(Integer, 1+xu), floor(Integer, 1+yu)
        # println(xi, ", ", yi)
        limit = (img2.zoombb.xmax - img2.zoombb.xmin) * 0.0125 # 100/8000
        annpts = annotation.ann.data.pts
        annidx = find_idx_of_nearest_pt(annpts, [xi, yi], limit)
        if annidx > 0
            idx = find_idx_of_nearest_pt(pts, [xi, yi], limit)
            println(idx, ": ", [xi, yi])
            annotation.ann.data.pts = hcat(annpts[:,1:annidx-1], 
                                                        annpts[:,annidx+1:end])
            ImageView.redraw(imgc)
            push!(pts_to_remove, idx)
        end
    end

    function end_edit()
        println("End edit")
        notify(e)
        bind(c, "<Button-3>", path->path)
        bind(win, "<Destroy>", path->path)
    end

    println("Right click to remove correspondences, then exit window.")
    wait(e)

    return pts_to_remove
end

"""
Display index k match pair meshes are two frames in movie to scroll between
"""
function review_matches_movie(meshset, k, step="post", downsample=2)
  matches = meshset.matches[k]
  src_index = matches.src_index
  dst_index = matches.dst_index
  println("display_matches_movie: ", (src_index, dst_index))
  src_mesh = meshset.meshes[find_index(meshset, src_index)]
  dst_mesh = meshset.meshes[find_index(meshset, dst_index)]

  if step == "post"
    src_nodes, dst_nodes = get_matched_points_t(meshset, k)
    src_index = (src_mesh.index[1], src_mesh.index[2], src_mesh.index[3]-1, src_mesh.index[4]-1)
    dst_index = (dst_mesh.index[1], dst_mesh.index[2], dst_mesh.index[3]-1, dst_mesh.index[4]-1)
    global_bb = get_global_bb(meshset)
    src_offset = [global_bb.i, global_bb.j]
    dst_offset = [global_bb.i, global_bb.j]
  else
    src_nodes, dst_nodes = get_matched_points(meshset, k)
    src_offset = src_mesh.disp
    dst_offset = dst_mesh.disp
  end

  src_nodes = hcat(src_nodes...)[1:2, :] .- src_offset
  dst_nodes = hcat(dst_nodes...)[1:2, :] .- dst_offset

  src_img = get_ufixed8_image(src_index)
  println(size(src_img))
  for i = 1:downsample
    src_img = restrict(src_img)
    src_nodes /= 2
  end
  dst_img = get_ufixed8_image(dst_index)
  println(size(dst_img))
  for i = 1:downsample
    dst_img = restrict(dst_img)
    dst_nodes /= 2
  end

  i_max = min(size(src_img,1), size(dst_img,1))
  j_max = min(size(src_img,2), size(dst_img,2))
  img = Image(cat(3, src_img[1:i_max, 1:j_max], dst_img[1:i_max, 1:j_max]), timedim=3)
  # imgc, img2 = view(make_isotropic(img))
  imgc, img2 = view(img)
  vectors = [src_nodes; dst_nodes]
  # an_pts, an_vectors = draw_vectors(imgc, img2, vectors)
  an_src_pts = draw_points(imgc, img2, src_nodes, RGB(1,0,0))
  an_dst_pts = draw_points(imgc, img2, dst_nodes, RGB(0,1,0))
  # pts_to_remove = edit_matches(imgc, img2, an_dst_pts)
  # return pts_to_remove
end

"""
Determine appropriate meshset solution method for meshset
"""
function resolve!(meshset::MeshSet)
  index = meshset.meshes[1].index
  if is_montaged(index)
  elseif is_prealigned(index)
    solve_meshset!(meshset)
  end
end

"""
Append 'EDITED' with a timestamp to update JLD filename
"""
function update_filename(fn)
  return string(fn[1:end-4], "_EDITED_", Dates.format(now(), "yyyymmddHHMMSS"), ".jld")
end

"""
Review all matches in the meshsets in given directory via method specified
"""
function review_matches(dir, method="movie")
  filenames = sort_dir(dir)
  for fn in filenames[1:1]
    println(joinpath(dir, fn))
    is_file_changed = false
    meshset = load(joinpath(dir, fn))["MeshSet"]
    # src_index = meshset.meshes[1].index
    # dst_index = meshset.meshes[2].index
    # meshset.meshes[1].index = (src_index[1:2]..., PREALIGNED_INDEX, PREALIGNED_INDEX)
    # meshset.meshes[2].index = (dst_index[1:2]..., PREALIGNED_INDEX, PREALIGNED_INDEX)
    new_path = update_filename(fn)
    log_file = open(joinpath(dir, string(new_path[1:end-4], ".txt")), "w")
    write(log_file, "Meshset from ", joinpath(dir, fn), "\n")
    for (k, matches) in enumerate(meshset.matches)
      println("Inspecting matches at index ", k,)
      if method=="images"
        @time src_bm_imgs, _ = get_blockmatch_images(meshset, k, "src", meshset.params["block_size"]-400)
        @time dst_bm_imgs, _ = get_blockmatch_images(meshset, k, "dst", meshset.params["block_size"]-400)
        @time filtered_imgs = create_filtered_images(src_bm_imgs, dst_bm_imgs)
        pts_to_remove = collect(edit_blockmatches(filtered_imgs))
      else
        pts_to_remove = review_matches_movie(meshset, k, "pre")
      end
      if length(pts_to_remove) > 0
        is_file_changed = true
        # save_blockmatch_imgs(meshset, k, pts_to_remove, joinpath(dir, "blockmatches"))
      end
      remove_matches_from_meshset!(pts_to_remove, k, meshset)
      log_line = string("Removed following matches from index ", k, ":\n")
      log_line = string(log_line, join(pts_to_remove, "\n"))
      write(log_file, log_line, "\n")
    end
    if is_file_changed
      resolve!(meshset)
      println("Saving JLD here: ", new_path)
      @time save(joinpath(dir, new_path), meshset)
    end
    close(log_file)
  end
end

"""
Convert matches object for section into filename string
"""
function matches2filename(meshset, k)
  src_index = meshset.matches[k].src_index
  dst_index = meshset.matches[k].dst_index
  return string(join(dst_index[1:2], ","), "-", join(src_index[1:2], ","))
end

"""
Convert cross correlogram to Image for saving
"""
function xcorr2Image(xc)
  return grayim((xc .+ 1)./2)
end

"""
Save match pair images w/ search & block radii at k index in meshset
"""
function save_blockmatch_imgs(meshset, k, blockmatch_ids=[], path=joinpath(ALIGNED_DIR, "blockmatches"))
  dir_path = joinpath(path, matches2filename(meshset, k))
  if !isdir(dir_path)
    mkdir(dir_path)
  end
  block_radius = meshset.params["block_size"]
  search_radius = meshset.params["search_r"]
  scale = meshset.params["scaling_factor"]
  combined_radius = search_radius+block_radius
  src_imgs, src_bounds = get_blockmatch_images(meshset, k, "src", combined_radius)
  dst_imgs, dst_bounds = get_blockmatch_images(meshset, k, "dst", block_radius)
  src_points, dst_points = get_matched_points(meshset, k)
  # dst_imgs_adjusted = get_blockmatch_images(meshset, k, "dst", block_radius)
  println("save_blockmatch_imgs")
  if blockmatch_ids == []
    blockmatch_ids = 1:length(src_imgs)
  end
  for (idx, (src_img, dst_img, src_point, src_bound)) in enumerate(zip(src_imgs, 
                                                                dst_imgs, 
                                                                src_points,
                                                                src_bounds))
    if idx in blockmatch_ids
      println(idx, "/", length(src_imgs))
      # xc = normxcorr2(src_img, dst_img)
      xc_peak, xc = get_max_xc_vector(dst_img, src_img)
      println(size(src_img))
      println(size(dst_img))
      println(size(xc))
      n = @sprintf("%03d", idx)
      img_mark = "good"
      dst_path = joinpath(dir_path, string(n , "_1_dst_", k, "_", img_mark, ".png"))
      imwrite(dst_img, dst_path)
      src_offset = src_point - collect(src_bound)
      src_path = joinpath(dir_path, string(n , "_2_src_", k, "_", img_mark, ".png"))
      imwrite_box(src_img, src_offset, block_radius, src_path)
      # imwrite(dst_img, joinpath(dir_path, string(n , "_dst_", k, "_", img_mark, ".jpg")))
      if !isnan(sum(xc))
        r_max = maximum(xc);
        rad = round(Int64, (size(xc, 1) - 1)/ 2)  
        ind = findfirst(r_max .== xc)
        xc_peak = [rem(ind, size(xc, 1)), cld(ind, size(xc, 1))]
        xc_path = joinpath(dir_path, string(n , "_3_xc_", k, "_", img_mark, ".png"))
        imwrite_box(xcorr2Image(xc'), xc_peak, 20, xc_path)
        # imwrite(xcorr2Image(xc'), joinpath(dir_path, string(n , "_xc_", k, "_", img_mark, ".jpg")))
      end
    end
  end
end

"""
Excerpt image in radius around given point
"""
function sliceimg(img, point, radius::Int64)
  point = ceil(Int64, point)
  imin = max(point[1]-radius, 1)
  jmin = max(point[2]-radius, 1)
  imax = min(point[1]+radius, size(img,1))
  jmax = min(point[2]+radius, size(img,2))
  return imin, jmin, imax, jmax
  # i_range = imin:imax
  # j_range = jmin:jmax
  # return img[i_range, j_range]
end

"""
Retrieve 1d array of block match pairs from the original images
"""
function get_blockmatch_images(meshset, k, mesh_type, radius)
  matches = meshset.matches[k]
  index = matches.(symbol(mesh_type, "_index"))
  mesh = meshset.meshes[find_index(meshset, index)]
  src_points, dst_points = get_matched_points(meshset, k)
  # src_points_t, dst_points_t = get_matched_points_t(meshset, k)
  scale = meshset.params["scaling_factor"]
  s = [scale 0 0; 0 scale 0; 0 0 1]
  img, _ = imwarp(get_ufixed8_image(mesh), s)
  offset = mesh.disp*scale
  # src_points *= scale
  # dst_points *= scale

  bm_imgs = []
  bm_bounds = []
  # for pt in (mesh_type == "src" ? src_points : dst_points)
  for pt in dst_points
    imin, jmin, imax, jmax = sliceimg(img, pt-offset, radius)
    push!(bm_imgs, img[imin:imax, jmin:jmax])
    push!(bm_bounds, (imin+offset[1], jmin+offset[2]))
    # push!(bm_imgs, sliceimg(img, pt-offset, radius))
  end
  return bm_imgs, bm_bounds
end

"""
Make one image from two blockmatch images, their difference, & their overlay
"""
function create_filtered_images(src_imgs, dst_imgs)
  gc(); gc();
  images = []
  for (n, (src_img, dst_img)) in enumerate(zip(src_imgs, dst_imgs))
    println(n, "/", length(src_imgs))
    src_img, dst_img = match_padding(src_img, dst_img)
    diff_img = convert(Image{RGB}, src_img-dst_img)
    imgA = grayim(Image(src_img))
    imgB = grayim(Image(dst_img))
    yellow_img = Overlay((imgA,imgB), (RGB(1,0,0), RGB(0,1,0)))
    pairA = convert(Image{RGB}, src_img)
    pairB = convert(Image{RGB}, dst_img)
    left_img = vcat(pairA, pairB)
    right_img = vcat(diff_img, yellow_img)
    img = hcat(left_img, right_img)
    push!(images, img)
  end
  return images
end

"""
Edit blockmatches with paging
"""
function edit_blockmatches(images)
  max_images_to_display = 60
  no_of_images = length(images)
  pages = ceil(Int, no_of_images / max_images_to_display)
  blockmatch_ids = Set()
  for page in 1:pages
    start = (page-1)*max_images_to_display + 1
    finish = start-1 + min(max_images_to_display, length(images)-start-1)
    println(start, finish)
    page_ids = display_blockmatches(images[start:finish], true, start)
    blockmatch_ids = union(blockmatch_ids, page_ids)
  end
  return blockmatch_ids
end

"""
Display blockmatch images in a grid to be clicked on
"""
function display_blockmatches(images, edit_mode_on=false, start_index=1)
  no_of_images = length(images)
  println("Displaying ", no_of_images, " images")
  grid_height = 6
  grid_width = 10
  # aspect_ratio = 1.6
  # grid_height = ceil(Int, sqrt(no_of_images/aspect_ratio))
  # grid_width = ceil(Int, aspect_ratio*grid_height)
  img_canvas_grid = canvasgrid(grid_height, grid_width, pad=1)
  match_index = 0
  blockmatch_ids = Set()
  e = Condition()

  function right_click(k)
    if in(k, blockmatch_ids)
      blockmatch_ids = setdiff(blockmatch_ids, Set(k))
    else
      push!(blockmatch_ids, k)
    end
    println(collect(blockmatch_ids))
  end

  for j = 1:grid_width
    for i = 1:grid_height
      match_index += 1
      n = match_index + start_index - 1
      if match_index <= no_of_images
        img = images[match_index]
        # imgc, img2 = view(img_canvas_grid[i,j], make_isotropic(img))
        imgc, img2 = view(img_canvas_grid[i,j], img)
        img_canvas = canvas(imgc)
        if edit_mode_on
          bind(img_canvas, "<Button-3>", path->right_click(n))
          win = Tk.toplevel(img_canvas)
          bind(win, "<Destroy>", path->notify(e))
        end
      end
    end
  end
  if edit_mode_on
    wait(e)
  end
  return blockmatch_ids
end

"""
`IMFUSE_SECTION` - Stitch section with seam overlays.
"""
function imfuse_section(meshset, downsample=3)
  img_reds = []
  img_greens = []
  bbs_reds = []
  bbs_greens = []
  # red_meshes = []
  # green_meshes = []
  for mesh in meshset.meshes
    img, bb = meshwarp(mesh)
    img = restrict(img)
    bb = BoundingBox(floor(Int,bb/2)..., size(img)[1], size(img)[2])
    if (mesh.index[3] + mesh.index[4]) % 2 == 1
      # push!(red_meshes, mesh)
      push!(img_reds, img)
      push!(bbs_reds, bb)
    else
      # push!(green_meshes, mesh)
      push!(img_greens, img)
      push!(bbs_greens, bb)
    end
  end
  # red_warps = pmap(meshwarp, red_meshes)
  # red_imgs, offsets = ([[x[i] for x in warps] for i=1:2]...)
  
  # green_warps = pmap(meshwarp, green_meshes)
  global_ref = snap_bb(sum(bbs_reds) + sum(bbs_greens))
  red_img = zeros(Int(global_ref.h), Int(global_ref.w))
  for (idx, (img, bb)) in enumerate(zip(img_reds, bbs_reds))
      println(idx)
      i = bb.i - global_ref.i+1
      j = bb.j - global_ref.j+1
      w = bb.w-1
      h = bb.h-1
      red_img[i:i+h, j:j+w] = max(red_img[i:i+h, j:j+w], img)
      img_reds[idx] = 0
      # gc()
  end
  green_img = zeros(Int(global_ref.h), Int(global_ref.w))
  for (idx, (img, bb)) in enumerate(zip(img_greens, bbs_greens))
      println(idx)
      i = bb.i - global_ref.i+1
      j = bb.j - global_ref.j+1
      w = bb.w-1
      h = bb.h-1
      green_img[i:i+h, j:j+w] = max(green_img[i:i+h, j:j+w], img)
      img_greens[idx] = 0
      # gc()
  end
  O, O_bb = imfuse(red_img, [0,0], green_img, [0,0])
  for i = 2:downsample
      O = restrict(O)
  end
  index = meshset.meshes[1].index
  imwrite(O, joinpath(MONTAGED_DIR, "review", string(join(index[1:2], ","), "_review.tif")))
end 

"""
Load meshset rendered images at downsampled rate as list
"""
function load_images(meshset, section_range=1:10, downsample=1)
  imgs = []
  for mesh in meshset.meshes[section_range]
    img = get_ufixed8_image((mesh.index[1:2]..., mesh.index[3]-1, mesh.index[4]-1))
    for i = 1:downsample
      img = restrict(img)
    end
    push!(imgs, img)
  end
  reduction = 2^downsample
  bounding_box = BoundingBox(GLOBAL_BB.i, GLOBAL_BB.j,
                              GLOBAL_BB.h/reduction, GLOBAL_BB.w/reduction)
  return imgs, bounding_box
end

"""
Load aligned meshset mesh nodes
"""
function load_nodes(meshset, section_range=1:10, downsample=1)
  global_bb = GLOBAL_BB
  global_nodes = []
  for mesh in meshset.meshes[section_range]
    nodes = hcat(mesh.nodes_t...) .- collect((global_bb.i, global_bb.j))
    for i = 1:downsample
      nodes /= 2
    end
    push!(global_nodes, [nodes])
  end
  return global_nodes
end

"""
Ripped from ImageView > navigation.jl
"""
function stop_playing!(state::ImageView.NavigationState)
    if state.timer != nothing
        close(state.timer)
        state.timer = nothing
    end
end

"""
Ripped from ImageView > navigation.jl
"""
function updatet(ctrls, state)
  Tk.set_value(ctrls.editt, string(state.t))
  Tk.set_value(ctrls.scalet, state.t)
  enableback = state.t > 1
  Tk.set_enabled(ctrls.stepback, enableback)
  Tk.set_enabled(ctrls.playback, enableback)
  enablefwd = state.t < state.tmax
  Tk.set_enabled(ctrls.stepfwd, enablefwd)
  Tk.set_enabled(ctrls.playfwd, enablefwd)
end

"""
Ripped from ImageView > navigation.jl
"""
function incrementt(inc, ctrls, state, showframe)
    state.t += inc
    updatet(ctrls, state)
    showframe(state)
end

"""
Ripped from ImageView > navigation.jl
"""
function playt(inc, ctrls, state, showframe)
    if !(state.fps > 0)
        error("Frame rate is not positive")
    end
    stop_playing!(state)
    dt = 1/state.fps
    state.timer = Timer(timer -> stept(inc, ctrls, state, showframe), dt, dt)
end

"""
Ripped from ImageView > navigation.jl
"""
function stept(inc, ctrls, state, showframe)
    if 1 <= state.t+inc <= state.tmax
        incrementt(inc, ctrls, state, showframe)
    else
        stop_playing!(state)
    end
end

"""
Create loop of the image
"""
function start_loop(imgc, img2, fps=6)
  state = imgc.navigationstate
  ctrls = imgc.navigationctrls
  showframe = state -> ImageView.reslice(imgc, img2, state)
  set_fps!(state, fps)

  if !(state.fps > 0)
      error("Frame rate is not positive")
  end
  stop_playing!(state)
  dt = 1/state.fps
  state.timer = Timer(timer -> loopt(ctrls, state, showframe), dt, dt)
end

"""
Higher level call for ImageView outputs
"""
function stop_loop(imgc)
  stop_playing!(imgc.navigationstate)
end

"""
Endlessly repeat forward loop (continuous stept)
"""
function loopt(ctrls, state, showframe)
  inc = 1
  if state.t+inc < 1 || state.tmax < state.t+inc
      state.t = 0
  end
  incrementt(inc, ctrls, state, showframe)
end

"""
Building on ImageView > navigation.jl
"""
function set_fps!(state, fps)
  state.fps = fps
end

"""
Cycle through sections of the stack movie, with images staged for easier viewing
"""
function stack_movie(meshset, section_range=(1:2), slice=(1:200,1:200), perm=[1,2,3])
  imgs = []
  for mesh in meshset.meshes[section_range]
    index = (mesh.index[1:2]..., mesh.index[3]-1, mesh.index[4]-1)
    img = get_h5_slice(get_h5_path(index), slice)
    push!(imgs, img)
  end

  println(slice)
  # img_stack = cat(3, imgs..., reverse(imgs[2:end-1])...)  # loop it
  img_stack = cat(3, imgs...)
  # img_stack = permutedims(cat(3, imgs...), perm)
  # img_movie = Image(img_stack, timedim=3)
  # if perm != [1,2,3]
    imgc, img2 = view(Image(permutedims(img_stack, [3,2,1]), timedim=3))
    start_loop(imgc, img2, 10)
    imgc, img2 = view(Image(permutedims(img_stack, [1,3,2]), timedim=3))
    start_loop(imgc, img2, 10)
    imgc, img2 = view(Image(permutedims(img_stack, [1,2,3]), timedim=3), pixelspacing=[1,1])
    start_loop(imgc, img2, 10)
  # end
  # start_loop(imgc, img2, 10)

  e = Condition()
  c = canvas(imgc)
  win = Tk.toplevel(c)

  function exit_movie()
    stop_loop(imgc)
    notify(e)
  end
  bind(win, "<Destroy>", path->notify(e))
  bind(win, "<Escape>", path->exit_movie())

  wait(e)
  destroy(win)
end

"""
Cycle through sections of the stack movie, with images staged for easier viewing
"""
function scan_stack_movie(imgs, bounding_box, divisions=12, perm=[1,2,3])
  ispan = ceil(Int64, bounding_box.h/divisions)
  jspan = ceil(Int64, bounding_box.w/divisions)
  overlap = 200

  overview = restrict(restrict(imgs[1]))
  imgc_overview, img2_overview = view(overview, pixelspacing=[1,1])
  box = annotate!(imgc_overview, img2_overview, AnnotationBox((0,0), (0,0),
                                                          color=RGB(0,1,0),
                                                          coord_order="yxyx"))

  println("Displaying axes with permutation: ", perm)
  for j=1:divisions, i=1:divisions
    imin = max((i-1)*ispan - overlap, 1)
    jmin = max((j-1)*jspan - overlap, 1)
    imax = min(i*ispan, floor(Int64, bounding_box.h))
    jmax = min(j*jspan, floor(Int64, bounding_box.w))
    slice_range = (imin:imax, jmin:jmax)

    box.ann.data.top = imin/4
    box.ann.data.left = jmin/4
    box.ann.data.bottom = imax/4
    box.ann.data.right = jmax/4
    ImageView.redraw(imgc_overview)

    println(slice_range)
    img_sections = [img[slice_range...] for img in imgs]
    img_stack = cat(3, img_sections..., reverse(img_sections[2:end-1])...)
    img_movie = Image(permutedims(img_stack, perm), timedim=3)
    imgc, img2 = view(img_movie, pixelspacing=[1,1])
    start_loop(imgc, img2, 6)

    e = Condition()
    c = canvas(imgc)
    win = Tk.toplevel(c)

    function exit_movie()
      stop_loop(imgc)
      destroy(win)
      notify(e)
    end
    bind(win, "<Destroy>", path->notify(e))
    bind(win, "<Escape>", path->exit_movie())

    wait(e)
  end
end

"""
Display index k match pair meshes are two frames in movie to scroll between
"""
function write_alignment_thumbnails(meshset, k, step="post")
  matches = meshset.matches[k]
  src_index = matches.src_index
  dst_index = matches.dst_index
  println("write_alignment_thumbnails: ", (src_index, dst_index))
  src_mesh = meshset.meshes[find_index(meshset, src_index)]
  dst_mesh = meshset.meshes[find_index(meshset, dst_index)]

  src_nodes, dst_nodes = get_matched_points_t(meshset, k)
  src_index = (src_mesh.index[1], src_mesh.index[2], src_mesh.index[3]-1, src_mesh.index[4]-1)
  dst_index = (dst_mesh.index[1], dst_mesh.index[2], dst_mesh.index[3]-1, dst_mesh.index[4]-1)
  global_bb = get_global_bb(meshset)
  src_offset = [global_bb.i, global_bb.j]
  # dst_offset = [global_bb.i, global_bb.j]

  scale = 0.0625
  s = [scale 0 0; 0 scale 0; 0 0 1]
  src_img, _ = imwarp(get_ufixed8_image(src_index), s)
  dst_img, _ = imwarp(get_ufixed8_image(dst_index), s)
  src_offset *= scale
  dst_offset *= scale

  O, O_bb = imfuse(src_img, src_offset, dst_img, dst_offset)

  src_nodes = (hcat(src_nodes...)[1:2, :] .- src_offset)*scale
  dst_nodes = (hcat(dst_nodes...)[1:2, :] .- dst_offset)*scale

  imgc, img2 = view(O, pixelspacing=[1,1])
  vectors = [src_nodes; dst_nodes]
  an_pts, an_vectors = draw_vectors(imgc, img2, vectors, RGB(0,0,1), RGB(1,0,1))
  draw_indices(imgc, img2, src_nodes)
  # an_src_pts = draw_points(imgc, img2, src_nodes, RGB(1,1,1), 2.0, 'x')
  # an_dst_pts = draw_points(imgc, img2, dst_nodes, RGB(0,0,0), 2.0, '+')

  thumbnail_fn = string(join(dst_index[1:2], ","), "-", join(src_index[1:2], ","), "_aligned_thumbnail.png")
  println("Writing ", thumbnail_fn)
  Cairo.write_to_png(imgc.c.back, joinpath(ALIGNED_DIR, "review", thumbnail_fn))
  destroy(toplevel(imgc))
end

"""
Cycle through JLD files in prealignment directory and save all blockmatches
"""
function save_prealignment_blockmatches(section_range::Array{Int64})
  filenames = sort_dir(PREALIGNED_DIR)[section_range]
  for filename in filenames
    println("Saving blockmatches from ", filename)
    meshset = JLD.load(joinpath(PREALIGNED_DIR, filename))["MeshSet"]
    save_blockmatch_imgs(meshset, 1, [], joinpath(PREALIGNED_DIR, "blockmatches"))
  end
end

"""
Cycle through prealignment blockmatch section_range
"""
function remove_prealignment_blockmatches(section_range::Array{Int64}, save_imgs=true)
  filenames = sort_dir(PREALIGNED_DIR)[section_range]
  for filename in filenames
    println("Select blockmatches to view from ", filename)
    meshset = JLD.load(joinpath(PREALIGNED_DIR, filename))["MeshSet"]
    blockmatch_ids = enter_array()
    if length(blockmatch_ids) > 0
      if save_imgs
        save_blockmatch_imgs(meshset, 1, blockmatch_ids, joinpath(PREALIGNED_DIR, "blockmatches"))
      end
      remove_matches_from_meshset!(blockmatch_ids, 1, meshset)
      edited_filename = update_filename(filename)
      println("Saving JLD here: ", edited_filename)
      @time save(joinpath(PREALIGNED_DIR, edited_filename), meshset)

      log_file = open(joinpath(PREALIGNED_DIR, string(edited_filename[1:end-4], ".txt")), "w")
      write(log_file, "Meshset from ", joinpath(PREALIGNED_DIR, filename), "\n")
      log_line = string("Removed following matches from index ", 1, ":\n")
      log_line = string(log_line, join(blockmatch_ids, "\n"))
      write(log_file, log_line, "\n")
      close(log_file)
    end
  end
end

"""
Provide prompt to user to enter int array elements one at a time
"""
function enter_array()
  println("Type integers and press return. Press return twice to end.")
  output = []
  is_int = true
  while is_int
    a = readline(STDIN)
    if typeof(parse(a)) == Int64
      push!(output, parse(a))
    else
      is_int = false
    end
  end
  return output
end

"""
Cycle through sections of the stack movie, with images staged for easier viewing
"""
function deprecated_movie(imgs, bounding_box, divisions=12)
  ispan = ceil(Int64, bounding_box.h/divisions)
  jspan = ceil(Int64, bounding_box.w/divisions)
  overlap = 200

  overview = restrict(restrict(imgs[1]))
  imgc_overview, img2_overview = view(overview, pixelspacing=[1,1])
  box = annotate!(imgc_overview, img2_overview, AnnotationBox((0,0), (0,0),
                                                          color=RGB(0,1,0),
                                                          coord_order="yxyx"))

  i = 0
  j = 1

  function next()
    i += 1
    if i >= divisions
      i = 1
      j += 1
      if j >= divisions
        notify(e)
      end
    end
    goto(i, j)
  end

  function back()
    i -= 1
    if i <= 0
      i = divisions
      j -= 1
      if j <= 0
        notify(e)
      end
    end
    goto(i, j)
  end

  function goto(i, j)
    imin = max((i-1)*ispan - overlap, 1)
    jmin = max((j-1)*jspan - overlap, 1)
    imax = min(i*ispan, floor(Int64, bounding_box.h))
    jmax = min(j*jspan, floor(Int64, bounding_box.w))
    slice_range = (imin:imax, jmin:jmax)

    box.ann.data.top = imin/4
    box.ann.data.left = jmin/4
    box.ann.data.bottom = imax/4
    box.ann.data.right = jmax/4
    ImageView.redraw(imgc_overview)

    println(slice_range)
    img_sections = [img[slice_range...] for img in imgs]
    img_movie = Image(cat(3, img_sections...), timedim=3)
    imgc, img2 = view(img_movie, pixelspacing=[1,1])

    c = canvas(imgc)
    win = Tk.toplevel(c)

    function exit_win()
      destroy(win)
      next()
    end
    bind(win, "<Destroy>", path->exit_win())
    bind(win, "<Escape>", path->exit_win())
  end

  if i == 0
    e = Condition()
    c_overview = canvas(imgc_overview)
    win_overview = Tk.toplevel(c_overview)

    bind(win_overview, "<Destroy>", path->notify(e))
    next()
  end
  wait(e)
end