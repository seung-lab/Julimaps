MESH_LENGTH_MONTAGE = 100
GLOBAL_OFFSETS_MONTAGE = true
BLOCKMATCH_SCALE_MONTAGE = 1.0
BLOCK_R_MONTAGE = 80
SEARCH_R_MONTAGE = 140
MONOBLOCK_SCALE_MONTAGE = 1
MONOBLOCK_MATCH_MONTAGE = false
MONOBLOCK_RATIO_MONTAGE = 0.4
MONOBLOCK_PADDING_MONTAGE = 0.0
MESH_SPRING_COEFF_MONTAGE = 1.0
MATCH_SPRING_COEFF_MONTAGE = 100.0 
FTOL_CG_MONTAGE = 1e-8
MAX_ITERS_MONTAGE = 2000
USE_CONJUGATE_GRADIENT_MONTAGE = true
ETA_GD_MONTAGE = 0.6
FTOL_GD_MONTAGE = 1e-8
ETA_NEWTON_MONTAGE = 0.6
FTOL_NEWTON_MONTAGE = 1e-16

MESH_LENGTH_PREALIGNMENT = 1500
GLOBAL_OFFSETS_PREALIGNMENT = false
BLOCKMATCH_SCALE_PREALIGNMENT = 0.1
BLOCK_R_PREALIGNMENT = 800
SEARCH_R_PREALIGNMENT = 3000
MONOBLOCK_SCALE_PREALIGNMENT = 0.15
MONOBLOCK_MATCH_PREALIGNMENT = true
MONOBLOCK_RATIO_PREALIGNMENT = 0.75
MONOBLOCK_PADDING_PREALIGNMENT = 0.0
# MESH_SPRING_COEFF_PREALIGNMENT = 1.0
# MATCH_SPRING_COEFF_PREALIGNMENT = 3.0 
# FTOL_CG_PREALIGNMENT = 1/1000
# MAX_ITERS_PREALIGNMENT = 1000
# USE_CONJUGATE_GRADIENT_ALIGNMENT = false

MESH_LENGTH_ALIGNMENT = 375
GLOBAL_OFFSETS_ALIGNMENT = true
BLOCKMATCH_SCALE_ALIGNMENT = 0.50
BLOCK_R_ALIGNMENT = 600
SEARCH_R_ALIGNMENT = 300
#BLOCK_R_ALIGNMENT = 122
#SEARCH_R_ALIGNMENT = 350
MONOBLOCK_SCALE_ALIGNMENT = 1
MONOBLOCK_MATCH_ALIGNMENT = false
MONOBLOCK_RATIO_ALIGNMENT = 0.4
MONOBLOCK_PADDING_ALIGNMENT = 0.0
MESH_SPRING_COEFF_ALIGNMENT = 1.0
MATCH_SPRING_COEFF_ALIGNMENT = 50.0
FTOL_CG_ALIGNMENT = 1e-8
MAX_ITERS_ALIGNMENT = 5000
USE_CONJUGATE_GRADIENT_ALIGNMENT = true
ETA_GD_ALIGNMENT = 0.01
FTOL_GD_ALIGNMENT = 3e-3
ETA_NEWTON_ALIGNMENT = 0.5
FTOL_NEWTON_ALIGNMENT = 1e-8

global PARAMS_MONTAGE = Dict(
			     "mesh" => Dict(
					"mesh_length" => MESH_LENGTH_MONTAGE), 
			     "match" => Dict(
					"blockmatch_scale" => BLOCKMATCH_SCALE_MONTAGE,
					"block_r" => BLOCK_R_MONTAGE, 
					"search_r" => SEARCH_R_MONTAGE,
					"highpass_sigma" => 0,
					"monoblock_scale" => MONOBLOCK_SCALE_MONTAGE, 
			#		"monoblock_padding" => MONOBLOCK_PADDING_MONTAGE, 
					"monoblock_ratio" => MONOBLOCK_RATIO_MONTAGE, 
					"monoblock_match" => MONOBLOCK_MATCH_MONTAGE,
					"depth" => 1,
					"reflexive" => false),
			     "solve" => Dict(
					"mesh_spring_coeff" => MESH_SPRING_COEFF_MONTAGE,
					"match_spring_coeff" => MATCH_SPRING_COEFF_MONTAGE,
					"ftol_cg" => FTOL_CG_MONTAGE,
					"max_iters" => MAX_ITERS_MONTAGE,
			     	"use_conjugate_gradient" => USE_CONJUGATE_GRADIENT_MONTAGE,
			     	"eta_gd" => ETA_GD_MONTAGE,
			     	"ftol_gd" => FTOL_GD_MONTAGE,
			     	"eta_newton" => ETA_NEWTON_MONTAGE,
			     	"ftol_newton" => FTOL_NEWTON_MONTAGE),
			     "filter" => Dict(
			     		"sigma_filter" => (:get_properties, >, 5, 0.8),
			     		"r_filter" => (:get_properties, <, 0.2, "r_max"),
						# "centered_norm_filter" => (:get_centered_norms, >, 20),
						"norm_filter" => (:get_norms_std_sigmas, >, 5)
			     		# "norm_filter" => (:get_norms_std_sigmas, >, 2.5)
					      ),
			     "render" => Dict(
			     		"crop" => [250, 250]
					      ),
			     "review" => Dict(
						# "too_few_corresps" => (:count_correspondences, <, 10),
						"rejected_ratio" => (:get_ratio_rejected, >, 0.66, 8),
						"ratio_edge_proximity" => (:get_ratio_edge_proximity, >, 0.95)
						#"norm_outliers" => (:count_outlier_norms, >, 0, 3), # too useless because they're so close to each other to begin with
						#"centered_norm" => (:get_maximum_centered_norm, >, 45)
					      ),
			     "registry" => Dict(
					"global_offsets" => GLOBAL_OFFSETS_MONTAGE
					)
			     )


global PARAMS_MONTAGE_FALLBACK = PARAMS_MONTAGE;

#PARAMS_MONTAGE_FALLBACK["match"]["search_r"] = 128;

global PARAMS_PREALIGNMENT = Dict(
			     "mesh" => Dict(
					"mesh_length" => MESH_LENGTH_PREALIGNMENT), 
			     "match" => Dict(
					"blockmatch_scale" => BLOCKMATCH_SCALE_PREALIGNMENT,
					"block_r" => BLOCK_R_PREALIGNMENT, 
					"search_r" => SEARCH_R_PREALIGNMENT,
					"monoblock_scale" => MONOBLOCK_SCALE_PREALIGNMENT, 
					"highpass_sigma" => 0,
					"monoblock_ratio" => MONOBLOCK_RATIO_PREALIGNMENT, 
					"monoblock_match" => MONOBLOCK_MATCH_PREALIGNMENT,
					"depth" => 1,
					"reflexive" => false),
			     "solve" => Dict(
					"method" => "regularized",
					"lambda" => 0.9),
					# "mesh_spring_coeff" => MESH_SPRING_COEFF_PREALIGNMENT,
					# "match_spring_coeff" => MATCH_SPRING_COEFF_PREALIGNMENT,
					# "ftol_cg" => FTOL_CG_PREALIGNMENT,
					# "max_iters" => MAX_ITERS_PREALIGNMENT,
					# "use_conjugate_gradient" => USE_CONJUGATE_GRADIENT_PREALIGNMENT,
					# "eta_gd" => ETA_GD_PREALIGNMENT,
					# "ftol_gd" => FTOL_GD_PREALIGNMENT,
					# "eta_newton" => ETA_NEWTON_PREALIGNMENTE,
					# "ftol_newton" => FTOL_NEWTON_PREALIGNMENT)
			     "filter" => Dict(
			     		"sigma_filter" => (:get_properties, >, 100, 0.5),
			     		"norm_filter" => (:get_norms_std_sigmas, >, 5)
					      ),
			     "render" => Dict(
					      ),
			     "review" => Dict(
				     	# "r_below" => (:count_filtered_properties, >, 0, "r_max", <, 0.2),
			     		"too_few_corresps" => (:count_correspondences, <, 3),
						"rejected_ratio" => (:get_ratio_rejected, >, 0.33, 0),
						"ratio_edge_proximity" => (:get_ratio_edge_proximity, >, 0.95),
						# "norm_outliers" => (:count_outlier_norms, >, 0, 3),
						"centered_norm" => (:get_maximum_centered_norm, >, SEARCH_R_PREALIGNMENT/2)
					      ),
			     "registry" => Dict(
					"global_offsets" => GLOBAL_OFFSETS_PREALIGNMENT
					)
			     )
global PARAMS_ALIGNMENT = Dict(
			     "mesh" => Dict(
					"mesh_length" => MESH_LENGTH_ALIGNMENT), 
			     "match" => Dict(
					"blockmatch_scale" => BLOCKMATCH_SCALE_ALIGNMENT,
					"block_r" => BLOCK_R_ALIGNMENT, 
					"search_r" => SEARCH_R_ALIGNMENT,
					"monoblock_scale" => MONOBLOCK_SCALE_ALIGNMENT,
					"highpass_sigma" => 10,
			#		"monoblock_padding" => MONOBLOCK_PADDING_ALIGNMENT, 
					"monoblock_ratio" => MONOBLOCK_RATIO_ALIGNMENT, 
					"monoblock_match" => MONOBLOCK_MATCH_ALIGNMENT,
					"depth" => 1,
					"reflexive" => false),
			     "solve" => Dict(
					"mesh_spring_coeff" => MESH_SPRING_COEFF_ALIGNMENT,
					"match_spring_coeff" => MATCH_SPRING_COEFF_ALIGNMENT,
					"ftol_cg" => FTOL_CG_ALIGNMENT,
					"max_iters" => MAX_ITERS_ALIGNMENT,
			     	"use_conjugate_gradient" => USE_CONJUGATE_GRADIENT_ALIGNMENT,
			     	"eta_gd" => ETA_GD_ALIGNMENT,
			     	"ftol_gd" => FTOL_GD_ALIGNMENT,
			     	"eta_newton" => ETA_NEWTON_ALIGNMENT,
			     	"ftol_newton" => FTOL_NEWTON_ALIGNMENT),
			     "filter" => Dict(
			     		"sigma_filter_high" => (:get_properties, >, 8, 0.95),
			     		"sigma_filter_mid" => (:get_properties, >, 75, 0.75),
			     		"sigma_filter_low" => (:get_properties, >, 100, 0.75),
			     		"r_filter" => (:get_properties, <, 0.025, "r_max"),
			     		# "norm_filter" => (:get_norms_std_sigmas, >, 5),
			     		"kurtosis_filter" => (:get_properties, >, 25, "src_kurtosis"),
			     		#"kurtosis_filter_edge" => (:get_properties, <, -1.15, "src_kurtosis"),
					"centered_norm_filter" => (:get_centered_norms, >, 250)
					      ),
			     "render" => Dict(
					      ),
			     "review" => Dict(
			     		"too_few_corresps" => (:count_correspondences, <, 100),
						"rejected_ratio" => (:get_ratio_rejected, >, 0.15),
						"ratio_edge_proximity" => (:get_ratio_edge_proximity, >, 0.95),
						# "norm_outliers" => (:count_outlier_norms, >, 0, 4),
						"centered_norm" => (:get_maximum_centered_norm, >, BLOCK_R_ALIGNMENT/2)
					      ),
			     "registry" => Dict(
					"global_offsets" => GLOBAL_OFFSETS_ALIGNMENT
					)
)
