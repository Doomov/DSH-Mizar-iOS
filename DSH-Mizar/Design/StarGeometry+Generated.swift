//
//  StarGeometry+Generated.swift
//  DSH-Mizar
//
//  The Mizar star's three-armed layer, in design units.
//
//  Generated -- do not edit. The shape is the owner's own reference layer,
//  measured into a radius profile in `scripts/make-star-geometry.py`: three
//  pointed arms and the notch between them, which keeps falling to 0.247 of
//  the tip. The six-armed icon is this path and its sixty-degree turn.
//
//  Regenerate: python3 scripts/make-star-geometry.py
//

import SwiftUI

enum StarGeometry {
    /// The box the path below is drawn in, in the icon's own units.
    static let designSize: CGFloat = 1024

    /// The layer under the front star, turned this far from it.
    ///
    /// 60 degrees is what turns three arms into the icon's six: each layer
    /// is three-fold symmetric, so 60 is the smallest offset that reads as two
    /// stars rather than one.
    static let backOffset: Double = 60

    /// The path, scaled to a `0...1` box with its top-left at the origin.
    ///
    /// Normalised rather than left in design units so a `Shape` can map it
    /// onto any frame with one multiply, and so a point on the curve means the
    /// same thing at 14 points as at 92.
    static func path() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0.5762, y: 0.456))
        path.addCurve(to: CGPoint(x: 0.5744, y: 0.4526), control1: CGPoint(x: 0.5755, y: 0.4549), control2: CGPoint(x: 0.575, y: 0.4538))
        path.addCurve(to: CGPoint(x: 0.5724, y: 0.4493), control1: CGPoint(x: 0.5737, y: 0.4515), control2: CGPoint(x: 0.5727, y: 0.4507))
        path.addCurve(to: CGPoint(x: 0.5726, y: 0.4443), control1: CGPoint(x: 0.5721, y: 0.4479), control2: CGPoint(x: 0.5726, y: 0.446))
        path.addCurve(to: CGPoint(x: 0.5724, y: 0.4392), control1: CGPoint(x: 0.5726, y: 0.4426), control2: CGPoint(x: 0.5728, y: 0.4407))
        path.addCurve(to: CGPoint(x: 0.5707, y: 0.4352), control1: CGPoint(x: 0.5721, y: 0.4377), control2: CGPoint(x: 0.5713, y: 0.4365))
        path.addCurve(to: CGPoint(x: 0.5688, y: 0.4312), control1: CGPoint(x: 0.5701, y: 0.4339), control2: CGPoint(x: 0.5692, y: 0.4328))
        path.addCurve(to: CGPoint(x: 0.568, y: 0.4258), control1: CGPoint(x: 0.5683, y: 0.4297), control2: CGPoint(x: 0.5683, y: 0.4276))
        path.addCurve(to: CGPoint(x: 0.5668, y: 0.4204), control1: CGPoint(x: 0.5676, y: 0.424), control2: CGPoint(x: 0.5672, y: 0.4223))
        path.addCurve(to: CGPoint(x: 0.5657, y: 0.4143), control1: CGPoint(x: 0.5664, y: 0.4185), control2: CGPoint(x: 0.5662, y: 0.4163))
        path.addCurve(to: CGPoint(x: 0.5643, y: 0.4082), control1: CGPoint(x: 0.5653, y: 0.4123), control2: CGPoint(x: 0.5646, y: 0.4107))
        path.addCurve(to: CGPoint(x: 0.564, y: 0.3995), control1: CGPoint(x: 0.564, y: 0.4057), control2: CGPoint(x: 0.5642, y: 0.4024))
        path.addCurve(to: CGPoint(x: 0.5632, y: 0.3906), control1: CGPoint(x: 0.5639, y: 0.3965), control2: CGPoint(x: 0.5637, y: 0.3933))
        path.addCurve(to: CGPoint(x: 0.5608, y: 0.3832), control1: CGPoint(x: 0.5626, y: 0.3879), control2: CGPoint(x: 0.5617, y: 0.3857))
        path.addCurve(to: CGPoint(x: 0.5579, y: 0.3759), control1: CGPoint(x: 0.5599, y: 0.3808), control2: CGPoint(x: 0.5587, y: 0.379))
        path.addCurve(to: CGPoint(x: 0.5561, y: 0.3646), control1: CGPoint(x: 0.5571, y: 0.3728), control2: CGPoint(x: 0.5568, y: 0.3684))
        path.addCurve(to: CGPoint(x: 0.5534, y: 0.3533), control1: CGPoint(x: 0.5553, y: 0.3609), control2: CGPoint(x: 0.5541, y: 0.358))
        path.addCurve(to: CGPoint(x: 0.5516, y: 0.3364), control1: CGPoint(x: 0.5526, y: 0.3486), control2: CGPoint(x: 0.5524, y: 0.3421))
        path.addCurve(to: CGPoint(x: 0.5484, y: 0.3194), control1: CGPoint(x: 0.5507, y: 0.3308), control2: CGPoint(x: 0.5496, y: 0.3255))
        path.addCurve(to: CGPoint(x: 0.5444, y: 0.2999), control1: CGPoint(x: 0.5472, y: 0.3134), control2: CGPoint(x: 0.546, y: 0.3064))
        path.addCurve(to: CGPoint(x: 0.5387, y: 0.2804), control1: CGPoint(x: 0.5427, y: 0.2934), control2: CGPoint(x: 0.5406, y: 0.2892))
        path.addCurve(to: CGPoint(x: 0.5333, y: 0.2473), control1: CGPoint(x: 0.5369, y: 0.2717), control2: CGPoint(x: 0.5356, y: 0.2583))
        path.addCurve(to: CGPoint(x: 0.525, y: 0.2143), control1: CGPoint(x: 0.531, y: 0.2363), control2: CGPoint(x: 0.5282, y: 0.2257))
        path.addCurve(to: CGPoint(x: 0.514, y: 0.1787), control1: CGPoint(x: 0.5218, y: 0.2029), control2: CGPoint(x: 0.5182, y: 0.1905))
        path.addCurve(to: CGPoint(x: 0.5, y: 0.1436), control1: CGPoint(x: 0.5099, y: 0.1669), control2: CGPoint(x: 0.5047, y: 0.1436))
        path.addCurve(to: CGPoint(x: 0.486, y: 0.1787), control1: CGPoint(x: 0.4953, y: 0.1436), control2: CGPoint(x: 0.4901, y: 0.1669))
        path.addCurve(to: CGPoint(x: 0.475, y: 0.2143), control1: CGPoint(x: 0.4818, y: 0.1905), control2: CGPoint(x: 0.4782, y: 0.2029))
        path.addCurve(to: CGPoint(x: 0.4667, y: 0.2473), control1: CGPoint(x: 0.4718, y: 0.2257), control2: CGPoint(x: 0.469, y: 0.2363))
        path.addCurve(to: CGPoint(x: 0.4613, y: 0.2804), control1: CGPoint(x: 0.4644, y: 0.2583), control2: CGPoint(x: 0.4631, y: 0.2717))
        path.addCurve(to: CGPoint(x: 0.4556, y: 0.2999), control1: CGPoint(x: 0.4594, y: 0.2892), control2: CGPoint(x: 0.4573, y: 0.2934))
        path.addCurve(to: CGPoint(x: 0.4516, y: 0.3194), control1: CGPoint(x: 0.454, y: 0.3064), control2: CGPoint(x: 0.4528, y: 0.3134))
        path.addCurve(to: CGPoint(x: 0.4484, y: 0.3364), control1: CGPoint(x: 0.4504, y: 0.3255), control2: CGPoint(x: 0.4493, y: 0.3308))
        path.addCurve(to: CGPoint(x: 0.4466, y: 0.3533), control1: CGPoint(x: 0.4476, y: 0.3421), control2: CGPoint(x: 0.4474, y: 0.3486))
        path.addCurve(to: CGPoint(x: 0.4439, y: 0.3646), control1: CGPoint(x: 0.4459, y: 0.358), control2: CGPoint(x: 0.4447, y: 0.3609))
        path.addCurve(to: CGPoint(x: 0.4421, y: 0.3759), control1: CGPoint(x: 0.4432, y: 0.3684), control2: CGPoint(x: 0.4429, y: 0.3728))
        path.addCurve(to: CGPoint(x: 0.4392, y: 0.3832), control1: CGPoint(x: 0.4413, y: 0.379), control2: CGPoint(x: 0.4401, y: 0.3808))
        path.addCurve(to: CGPoint(x: 0.4368, y: 0.3906), control1: CGPoint(x: 0.4383, y: 0.3857), control2: CGPoint(x: 0.4374, y: 0.3879))
        path.addCurve(to: CGPoint(x: 0.436, y: 0.3995), control1: CGPoint(x: 0.4363, y: 0.3933), control2: CGPoint(x: 0.4361, y: 0.3965))
        path.addCurve(to: CGPoint(x: 0.4357, y: 0.4082), control1: CGPoint(x: 0.4358, y: 0.4024), control2: CGPoint(x: 0.436, y: 0.4057))
        path.addCurve(to: CGPoint(x: 0.4343, y: 0.4143), control1: CGPoint(x: 0.4354, y: 0.4107), control2: CGPoint(x: 0.4347, y: 0.4123))
        path.addCurve(to: CGPoint(x: 0.4332, y: 0.4204), control1: CGPoint(x: 0.4338, y: 0.4163), control2: CGPoint(x: 0.4336, y: 0.4185))
        path.addCurve(to: CGPoint(x: 0.432, y: 0.4258), control1: CGPoint(x: 0.4328, y: 0.4223), control2: CGPoint(x: 0.4324, y: 0.424))
        path.addCurve(to: CGPoint(x: 0.4312, y: 0.4312), control1: CGPoint(x: 0.4317, y: 0.4276), control2: CGPoint(x: 0.4317, y: 0.4297))
        path.addCurve(to: CGPoint(x: 0.4293, y: 0.4352), control1: CGPoint(x: 0.4308, y: 0.4328), control2: CGPoint(x: 0.4299, y: 0.4339))
        path.addCurve(to: CGPoint(x: 0.4276, y: 0.4392), control1: CGPoint(x: 0.4287, y: 0.4365), control2: CGPoint(x: 0.4279, y: 0.4377))
        path.addCurve(to: CGPoint(x: 0.4274, y: 0.4443), control1: CGPoint(x: 0.4272, y: 0.4407), control2: CGPoint(x: 0.4274, y: 0.4426))
        path.addCurve(to: CGPoint(x: 0.4276, y: 0.4493), control1: CGPoint(x: 0.4274, y: 0.446), control2: CGPoint(x: 0.4279, y: 0.4479))
        path.addCurve(to: CGPoint(x: 0.4256, y: 0.4526), control1: CGPoint(x: 0.4273, y: 0.4507), control2: CGPoint(x: 0.4263, y: 0.4515))
        path.addCurve(to: CGPoint(x: 0.4238, y: 0.456), control1: CGPoint(x: 0.425, y: 0.4538), control2: CGPoint(x: 0.4241, y: 0.4555))
        path.addCurve(to: CGPoint(x: 0.4238, y: 0.456), control1: CGPoint(x: 0.4235, y: 0.4566), control2: CGPoint(x: 0.4242, y: 0.4555))
        path.addCurve(to: CGPoint(x: 0.4218, y: 0.4593), control1: CGPoint(x: 0.4235, y: 0.4566), control2: CGPoint(x: 0.4225, y: 0.4582))
        path.addCurve(to: CGPoint(x: 0.4199, y: 0.4626), control1: CGPoint(x: 0.4211, y: 0.4604), control2: CGPoint(x: 0.4209, y: 0.4617))
        path.addCurve(to: CGPoint(x: 0.4155, y: 0.465), control1: CGPoint(x: 0.4188, y: 0.4636), control2: CGPoint(x: 0.4169, y: 0.4642))
        path.addCurve(to: CGPoint(x: 0.4111, y: 0.4677), control1: CGPoint(x: 0.414, y: 0.4658), control2: CGPoint(x: 0.4123, y: 0.4666))
        path.addCurve(to: CGPoint(x: 0.4085, y: 0.4712), control1: CGPoint(x: 0.41, y: 0.4687), control2: CGPoint(x: 0.4094, y: 0.47))
        path.addCurve(to: CGPoint(x: 0.4061, y: 0.4748), control1: CGPoint(x: 0.4077, y: 0.4724), control2: CGPoint(x: 0.4072, y: 0.4737))
        path.addCurve(to: CGPoint(x: 0.4018, y: 0.4782), control1: CGPoint(x: 0.405, y: 0.476), control2: CGPoint(x: 0.4032, y: 0.477))
        path.addCurve(to: CGPoint(x: 0.3976, y: 0.482), control1: CGPoint(x: 0.4004, y: 0.4794), control2: CGPoint(x: 0.3991, y: 0.4807))
        path.addCurve(to: CGPoint(x: 0.3929, y: 0.4859), control1: CGPoint(x: 0.3962, y: 0.4832), control2: CGPoint(x: 0.3945, y: 0.4845))
        path.addCurve(to: CGPoint(x: 0.3884, y: 0.4902), control1: CGPoint(x: 0.3914, y: 0.4873), control2: CGPoint(x: 0.3904, y: 0.4887))
        path.addCurve(to: CGPoint(x: 0.3809, y: 0.4948), control1: CGPoint(x: 0.3864, y: 0.4917), control2: CGPoint(x: 0.3834, y: 0.4932))
        path.addCurve(to: CGPoint(x: 0.3737, y: 0.5), control1: CGPoint(x: 0.3785, y: 0.4964), control2: CGPoint(x: 0.3758, y: 0.4982))
        path.addCurve(to: CGPoint(x: 0.3685, y: 0.5057), control1: CGPoint(x: 0.3716, y: 0.5018), control2: CGPoint(x: 0.3702, y: 0.5038))
        path.addCurve(to: CGPoint(x: 0.3635, y: 0.5119), control1: CGPoint(x: 0.3668, y: 0.5077), control2: CGPoint(x: 0.3658, y: 0.5097))
        path.addCurve(to: CGPoint(x: 0.3547, y: 0.5191), control1: CGPoint(x: 0.3612, y: 0.5142), control2: CGPoint(x: 0.3576, y: 0.5166))
        path.addCurve(to: CGPoint(x: 0.3463, y: 0.5271), control1: CGPoint(x: 0.3518, y: 0.5217), control2: CGPoint(x: 0.35, y: 0.5241))
        path.addCurve(to: CGPoint(x: 0.3326, y: 0.5371), control1: CGPoint(x: 0.3426, y: 0.5301), control2: CGPoint(x: 0.337, y: 0.5336))
        path.addCurve(to: CGPoint(x: 0.3194, y: 0.5484), control1: CGPoint(x: 0.3281, y: 0.5407), control2: CGPoint(x: 0.3241, y: 0.5443))
        path.addCurve(to: CGPoint(x: 0.3045, y: 0.5616), control1: CGPoint(x: 0.3148, y: 0.5525), control2: CGPoint(x: 0.3094, y: 0.557))
        path.addCurve(to: CGPoint(x: 0.2905, y: 0.5763), control1: CGPoint(x: 0.2997, y: 0.5663), control2: CGPoint(x: 0.2972, y: 0.5703))
        path.addCurve(to: CGPoint(x: 0.2645, y: 0.5975), control1: CGPoint(x: 0.2838, y: 0.5822), control2: CGPoint(x: 0.2729, y: 0.59))
        path.addCurve(to: CGPoint(x: 0.2401, y: 0.6212), control1: CGPoint(x: 0.2561, y: 0.605), control2: CGPoint(x: 0.2484, y: 0.6127))
        path.addCurve(to: CGPoint(x: 0.2147, y: 0.6485), control1: CGPoint(x: 0.2318, y: 0.6297), control2: CGPoint(x: 0.2228, y: 0.639))
        path.addCurve(to: CGPoint(x: 0.1913, y: 0.6782), control1: CGPoint(x: 0.2066, y: 0.658), control2: CGPoint(x: 0.189, y: 0.6742))
        path.addCurve(to: CGPoint(x: 0.2287, y: 0.6728), control1: CGPoint(x: 0.1936, y: 0.6823), control2: CGPoint(x: 0.2165, y: 0.6751))
        path.addCurve(to: CGPoint(x: 0.2651, y: 0.6645), control1: CGPoint(x: 0.241, y: 0.6705), control2: CGPoint(x: 0.2536, y: 0.6674))
        path.addCurve(to: CGPoint(x: 0.2978, y: 0.6552), control1: CGPoint(x: 0.2766, y: 0.6616), control2: CGPoint(x: 0.2871, y: 0.6587))
        path.addCurve(to: CGPoint(x: 0.3292, y: 0.6433), control1: CGPoint(x: 0.3085, y: 0.6516), control2: CGPoint(x: 0.3207, y: 0.6461))
        path.addCurve(to: CGPoint(x: 0.3489, y: 0.6385), control1: CGPoint(x: 0.3377, y: 0.6405), control2: CGPoint(x: 0.3425, y: 0.6403))
        path.addCurve(to: CGPoint(x: 0.3678, y: 0.6322), control1: CGPoint(x: 0.3553, y: 0.6366), control2: CGPoint(x: 0.362, y: 0.6342))
        path.addCurve(to: CGPoint(x: 0.3841, y: 0.6264), control1: CGPoint(x: 0.3737, y: 0.6302), control2: CGPoint(x: 0.3788, y: 0.6285))
        path.addCurve(to: CGPoint(x: 0.3997, y: 0.6196), control1: CGPoint(x: 0.3894, y: 0.6243), control2: CGPoint(x: 0.3952, y: 0.6213))
        path.addCurve(to: CGPoint(x: 0.4108, y: 0.6163), control1: CGPoint(x: 0.4041, y: 0.6179), control2: CGPoint(x: 0.4072, y: 0.6175))
        path.addCurve(to: CGPoint(x: 0.4214, y: 0.6122), control1: CGPoint(x: 0.4144, y: 0.615), control2: CGPoint(x: 0.4184, y: 0.6131))
        path.addCurve(to: CGPoint(x: 0.4293, y: 0.611), control1: CGPoint(x: 0.4245, y: 0.6113), control2: CGPoint(x: 0.4267, y: 0.6115))
        path.addCurve(to: CGPoint(x: 0.4368, y: 0.6094), control1: CGPoint(x: 0.4318, y: 0.6106), control2: CGPoint(x: 0.4342, y: 0.6103))
        path.addCurve(to: CGPoint(x: 0.445, y: 0.6057), control1: CGPoint(x: 0.4395, y: 0.6085), control2: CGPoint(x: 0.4423, y: 0.607))
        path.addCurve(to: CGPoint(x: 0.4526, y: 0.6016), control1: CGPoint(x: 0.4476, y: 0.6044), control2: CGPoint(x: 0.4504, y: 0.6026))
        path.addCurve(to: CGPoint(x: 0.4587, y: 0.5998), control1: CGPoint(x: 0.4549, y: 0.6006), control2: CGPoint(x: 0.4567, y: 0.6004))
        path.addCurve(to: CGPoint(x: 0.4645, y: 0.5977), control1: CGPoint(x: 0.4606, y: 0.5991), control2: CGPoint(x: 0.4626, y: 0.5983))
        path.addCurve(to: CGPoint(x: 0.4698, y: 0.5959), control1: CGPoint(x: 0.4663, y: 0.597), control2: CGPoint(x: 0.468, y: 0.5966))
        path.addCurve(to: CGPoint(x: 0.4748, y: 0.5939), control1: CGPoint(x: 0.4715, y: 0.5953), control2: CGPoint(x: 0.4733, y: 0.5943))
        path.addCurve(to: CGPoint(x: 0.4792, y: 0.5936), control1: CGPoint(x: 0.4764, y: 0.5935), control2: CGPoint(x: 0.4778, y: 0.5938))
        path.addCurve(to: CGPoint(x: 0.4836, y: 0.5931), control1: CGPoint(x: 0.4807, y: 0.5935), control2: CGPoint(x: 0.4821, y: 0.5936))
        path.addCurve(to: CGPoint(x: 0.4881, y: 0.5907), control1: CGPoint(x: 0.485, y: 0.5926), control2: CGPoint(x: 0.4866, y: 0.5915))
        path.addCurve(to: CGPoint(x: 0.4923, y: 0.5881), control1: CGPoint(x: 0.4895, y: 0.5899), control2: CGPoint(x: 0.4909, y: 0.5885))
        path.addCurve(to: CGPoint(x: 0.4962, y: 0.5881), control1: CGPoint(x: 0.4936, y: 0.5876), control2: CGPoint(x: 0.4949, y: 0.5881))
        path.addCurve(to: CGPoint(x: 0.5, y: 0.5879), control1: CGPoint(x: 0.4974, y: 0.5881), control2: CGPoint(x: 0.4987, y: 0.5879))
        path.addCurve(to: CGPoint(x: 0.5038, y: 0.5881), control1: CGPoint(x: 0.5013, y: 0.5879), control2: CGPoint(x: 0.5026, y: 0.5881))
        path.addCurve(to: CGPoint(x: 0.5077, y: 0.5881), control1: CGPoint(x: 0.5051, y: 0.5881), control2: CGPoint(x: 0.5064, y: 0.5876))
        path.addCurve(to: CGPoint(x: 0.5119, y: 0.5907), control1: CGPoint(x: 0.5091, y: 0.5885), control2: CGPoint(x: 0.5105, y: 0.5899))
        path.addCurve(to: CGPoint(x: 0.5164, y: 0.5931), control1: CGPoint(x: 0.5134, y: 0.5915), control2: CGPoint(x: 0.515, y: 0.5926))
        path.addCurve(to: CGPoint(x: 0.5208, y: 0.5936), control1: CGPoint(x: 0.5179, y: 0.5936), control2: CGPoint(x: 0.5193, y: 0.5935))
        path.addCurve(to: CGPoint(x: 0.5252, y: 0.5939), control1: CGPoint(x: 0.5222, y: 0.5938), control2: CGPoint(x: 0.5236, y: 0.5935))
        path.addCurve(to: CGPoint(x: 0.5302, y: 0.5959), control1: CGPoint(x: 0.5267, y: 0.5943), control2: CGPoint(x: 0.5285, y: 0.5953))
        path.addCurve(to: CGPoint(x: 0.5355, y: 0.5977), control1: CGPoint(x: 0.532, y: 0.5966), control2: CGPoint(x: 0.5337, y: 0.597))
        path.addCurve(to: CGPoint(x: 0.5413, y: 0.5998), control1: CGPoint(x: 0.5374, y: 0.5983), control2: CGPoint(x: 0.5394, y: 0.5991))
        path.addCurve(to: CGPoint(x: 0.5474, y: 0.6016), control1: CGPoint(x: 0.5433, y: 0.6004), control2: CGPoint(x: 0.5451, y: 0.6006))
        path.addCurve(to: CGPoint(x: 0.555, y: 0.6057), control1: CGPoint(x: 0.5496, y: 0.6026), control2: CGPoint(x: 0.5524, y: 0.6044))
        path.addCurve(to: CGPoint(x: 0.5632, y: 0.6094), control1: CGPoint(x: 0.5577, y: 0.607), control2: CGPoint(x: 0.5605, y: 0.6085))
        path.addCurve(to: CGPoint(x: 0.5707, y: 0.611), control1: CGPoint(x: 0.5658, y: 0.6103), control2: CGPoint(x: 0.5682, y: 0.6106))
        path.addCurve(to: CGPoint(x: 0.5786, y: 0.6122), control1: CGPoint(x: 0.5733, y: 0.6115), control2: CGPoint(x: 0.5755, y: 0.6113))
        path.addCurve(to: CGPoint(x: 0.5892, y: 0.6163), control1: CGPoint(x: 0.5816, y: 0.6131), control2: CGPoint(x: 0.5856, y: 0.615))
        path.addCurve(to: CGPoint(x: 0.6003, y: 0.6196), control1: CGPoint(x: 0.5928, y: 0.6175), control2: CGPoint(x: 0.5959, y: 0.6179))
        path.addCurve(to: CGPoint(x: 0.6159, y: 0.6264), control1: CGPoint(x: 0.6048, y: 0.6213), control2: CGPoint(x: 0.6106, y: 0.6243))
        path.addCurve(to: CGPoint(x: 0.6322, y: 0.6322), control1: CGPoint(x: 0.6212, y: 0.6285), control2: CGPoint(x: 0.6263, y: 0.6302))
        path.addCurve(to: CGPoint(x: 0.6511, y: 0.6385), control1: CGPoint(x: 0.638, y: 0.6342), control2: CGPoint(x: 0.6447, y: 0.6366))
        path.addCurve(to: CGPoint(x: 0.6708, y: 0.6433), control1: CGPoint(x: 0.6575, y: 0.6403), control2: CGPoint(x: 0.6623, y: 0.6405))
        path.addCurve(to: CGPoint(x: 0.7022, y: 0.6552), control1: CGPoint(x: 0.6793, y: 0.6461), control2: CGPoint(x: 0.6915, y: 0.6516))
        path.addCurve(to: CGPoint(x: 0.7349, y: 0.6645), control1: CGPoint(x: 0.7129, y: 0.6587), control2: CGPoint(x: 0.7234, y: 0.6616))
        path.addCurve(to: CGPoint(x: 0.7713, y: 0.6728), control1: CGPoint(x: 0.7464, y: 0.6674), control2: CGPoint(x: 0.759, y: 0.6705))
        path.addCurve(to: CGPoint(x: 0.8087, y: 0.6782), control1: CGPoint(x: 0.7835, y: 0.6751), control2: CGPoint(x: 0.8064, y: 0.6823))
        path.addCurve(to: CGPoint(x: 0.7853, y: 0.6485), control1: CGPoint(x: 0.811, y: 0.6742), control2: CGPoint(x: 0.7934, y: 0.658))
        path.addCurve(to: CGPoint(x: 0.7599, y: 0.6212), control1: CGPoint(x: 0.7772, y: 0.639), control2: CGPoint(x: 0.7682, y: 0.6297))
        path.addCurve(to: CGPoint(x: 0.7355, y: 0.5975), control1: CGPoint(x: 0.7516, y: 0.6127), control2: CGPoint(x: 0.7439, y: 0.605))
        path.addCurve(to: CGPoint(x: 0.7095, y: 0.5763), control1: CGPoint(x: 0.7271, y: 0.59), control2: CGPoint(x: 0.7162, y: 0.5822))
        path.addCurve(to: CGPoint(x: 0.6955, y: 0.5616), control1: CGPoint(x: 0.7028, y: 0.5703), control2: CGPoint(x: 0.7003, y: 0.5663))
        path.addCurve(to: CGPoint(x: 0.6806, y: 0.5484), control1: CGPoint(x: 0.6906, y: 0.557), control2: CGPoint(x: 0.6852, y: 0.5525))
        path.addCurve(to: CGPoint(x: 0.6674, y: 0.5371), control1: CGPoint(x: 0.6759, y: 0.5443), control2: CGPoint(x: 0.6719, y: 0.5407))
        path.addCurve(to: CGPoint(x: 0.6537, y: 0.5271), control1: CGPoint(x: 0.663, y: 0.5336), control2: CGPoint(x: 0.6574, y: 0.5301))
        path.addCurve(to: CGPoint(x: 0.6453, y: 0.5191), control1: CGPoint(x: 0.65, y: 0.5241), control2: CGPoint(x: 0.6482, y: 0.5217))
        path.addCurve(to: CGPoint(x: 0.6365, y: 0.5119), control1: CGPoint(x: 0.6424, y: 0.5166), control2: CGPoint(x: 0.6388, y: 0.5142))
        path.addCurve(to: CGPoint(x: 0.6315, y: 0.5057), control1: CGPoint(x: 0.6342, y: 0.5097), control2: CGPoint(x: 0.6332, y: 0.5077))
        path.addCurve(to: CGPoint(x: 0.6263, y: 0.5), control1: CGPoint(x: 0.6298, y: 0.5038), control2: CGPoint(x: 0.6284, y: 0.5018))
        path.addCurve(to: CGPoint(x: 0.6191, y: 0.4948), control1: CGPoint(x: 0.6242, y: 0.4982), control2: CGPoint(x: 0.6215, y: 0.4964))
        path.addCurve(to: CGPoint(x: 0.6116, y: 0.4902), control1: CGPoint(x: 0.6166, y: 0.4932), control2: CGPoint(x: 0.6136, y: 0.4917))
        path.addCurve(to: CGPoint(x: 0.6071, y: 0.4859), control1: CGPoint(x: 0.6096, y: 0.4887), control2: CGPoint(x: 0.6086, y: 0.4873))
        path.addCurve(to: CGPoint(x: 0.6024, y: 0.482), control1: CGPoint(x: 0.6055, y: 0.4845), control2: CGPoint(x: 0.6038, y: 0.4832))
        path.addCurve(to: CGPoint(x: 0.5982, y: 0.4782), control1: CGPoint(x: 0.6009, y: 0.4807), control2: CGPoint(x: 0.5996, y: 0.4794))
        path.addCurve(to: CGPoint(x: 0.5939, y: 0.4748), control1: CGPoint(x: 0.5968, y: 0.477), control2: CGPoint(x: 0.595, y: 0.476))
        path.addCurve(to: CGPoint(x: 0.5915, y: 0.4712), control1: CGPoint(x: 0.5928, y: 0.4737), control2: CGPoint(x: 0.5923, y: 0.4724))
        path.addCurve(to: CGPoint(x: 0.5889, y: 0.4677), control1: CGPoint(x: 0.5906, y: 0.47), control2: CGPoint(x: 0.59, y: 0.4687))
        path.addCurve(to: CGPoint(x: 0.5845, y: 0.465), control1: CGPoint(x: 0.5877, y: 0.4666), control2: CGPoint(x: 0.586, y: 0.4658))
        path.addCurve(to: CGPoint(x: 0.5801, y: 0.4626), control1: CGPoint(x: 0.5831, y: 0.4642), control2: CGPoint(x: 0.5812, y: 0.4636))
        path.addCurve(to: CGPoint(x: 0.5782, y: 0.4593), control1: CGPoint(x: 0.5791, y: 0.4617), control2: CGPoint(x: 0.5789, y: 0.4604))
        path.addCurve(to: CGPoint(x: 0.5762, y: 0.456), control1: CGPoint(x: 0.5775, y: 0.4582), control2: CGPoint(x: 0.5768, y: 0.4571))
        path.closeSubpath()
        return path
    }
}
