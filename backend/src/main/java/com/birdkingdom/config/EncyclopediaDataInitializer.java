package com.birdkingdom.config;

import com.birdkingdom.entity.BirdEncyclopedia;
import com.birdkingdom.entity.ColorGene;
import com.birdkingdom.entity.Symptom;
import com.birdkingdom.repository.BirdEncyclopediaRepository;
import com.birdkingdom.repository.ColorGeneRepository;
import com.birdkingdom.repository.SymptomRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class EncyclopediaDataInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(EncyclopediaDataInitializer.class);

    private final BirdEncyclopediaRepository encyclopediaRepository;
    private final SymptomRepository symptomRepository;
    private final ColorGeneRepository colorGeneRepository;

    public EncyclopediaDataInitializer(BirdEncyclopediaRepository encyclopediaRepository,
                                       SymptomRepository symptomRepository,
                                       ColorGeneRepository colorGeneRepository) {
        this.encyclopediaRepository = encyclopediaRepository;
        this.symptomRepository = symptomRepository;
        this.colorGeneRepository = colorGeneRepository;
    }

    @Override
    public void run(String... args) {
        initBirdEncyclopedia();
        initSymptoms();
        initColorGenes();
    }

    private void initBirdEncyclopedia() {
        if (encyclopediaRepository.count() > 0) {
            log.info("鸟类百科数据已存在，跳过初始化");
            return;
        }

        log.info("初始化鸟类百科数据...");

        encyclopediaRepository.save(createBird("文鸟", "Lonchura striata", "雀形目",
                "适合新手,群居,易繁殖",
                "文鸟是最受欢迎的观赏鸟之一，性格温顺，叫声悦耳。原产于东南亚，现已广泛人工繁殖。",
                "主食为谷物种子，需补充青菜和钙质。保持清洁饮水，定期日光浴。",
                "东南亚热带地区", 8, "#8B4513"));

        encyclopediaRepository.save(createBird("牡丹鹦鹉", "Agapornis", "鹦形目",
                "情侣鸟,活泼,色彩丰富",
                "牡丹鹦鹉又称爱情鸟，因其成双成对的习性而得名。羽色艳丽，性格活泼好动。",
                "以混合种子为主，搭配新鲜蔬果。需要较大活动空间和玩具。",
                "非洲大陆", 15, "#2E8B57"));

        encyclopediaRepository.save(createBird("虎皮鹦鹉", "Melopsittacus undulatus", "鹦形目",
                "会说话,聪明,适合新手",
                "虎皮鹦鹉是最常见的宠物鹦鹉，因背部条纹似虎皮而得名。聪明活泼，可训练说话。",
                "谷物种子为主，定期提供蔬菜水果。需要磨嘴石和钙质补充。",
                "澳大利亚内陆", 10, "#4169E1"));

        encyclopediaRepository.save(createBird("金丝雀", "Serinus canaria", "雀形目",
                "歌声优美,独居,观赏性强",
                "金丝雀以其优美的歌声闻名，是传统的笼养观赏鸟。雄鸟善鸣，羽色金黄。",
                "专用金丝雀粮为主，补充蛋黄和青菜。保持安静环境有助于鸣唱。",
                "加那利群岛", 12, "#FFD700"));

        encyclopediaRepository.save(createBird("珍珠鸟", "Taeniopygia guttata", "雀形目",
                "小巧可爱,群居,易饲养",
                "珍珠鸟体型小巧，羽毛上有珍珠般的白色斑点。性格温和，适合群养。",
                "小米、谷子为主食，需要沙砾帮助消化。喜欢水浴。",
                "澳大利亚", 7, "#DC143C"));

        encyclopediaRepository.save(createBird("玄凤鹦鹉", "Nymphicus hollandicus", "鹦形目",
                "亲人,冠羽,中型",
                "玄凤鹦鹉头顶有漂亮的冠羽，性格温顺亲人。可以学会简单的口哨和词语。",
                "滋养丸搭配种子，新鲜蔬果不可少。需要大笼子和陪伴时间。",
                "澳大利亚", 20, "#FFA500"));

        log.info("鸟类百科数据初始化完成");
    }

    private BirdEncyclopedia createBird(String name, String scientificName, String category,
                                        String tags, String description, String feedingTips,
                                        String habitat, int lifespan, String colorHex) {
        BirdEncyclopedia bird = new BirdEncyclopedia();
        bird.setName(name);
        bird.setScientificName(scientificName);
        bird.setCategory(category);
        bird.setTags(tags);
        bird.setDescription(description);
        bird.setFeedingTips(feedingTips);
        bird.setHabitat(habitat);
        bird.setLifespan(lifespan);
        bird.setColorHex(colorHex);
        return bird;
    }

    private void initSymptoms() {
        if (symptomRepository.count() > 0) {
            log.info("症状数据已存在，跳过初始化");
            return;
        }

        log.info("初始化症状数据...");

        symptomRepository.save(createSymptom("掉毛明显",
                "羽毛大量脱落，超出正常换羽范围",
                "换羽期,营养不良,寄生虫,压力过大,皮肤病",
                "检查是否为正常换羽期,补充蛋白质和维生素,保持环境清洁,如持续严重请就医",
                "medium"));

        symptomRepository.save(createSymptom("精神萎靡",
                "活动减少，嗜睡，反应迟钝",
                "生病初期,温度不适,营养不足,年龄老化",
                "保持适宜温度（25-28℃）,提供安静休息环境,观察是否有其他症状,建议尽快就医检查",
                "high"));

        symptomRepository.save(createSymptom("食欲下降",
                "进食量明显减少或拒食",
                "消化问题,口腔疾病,环境变化,食物不新鲜",
                "更换新鲜食物,检查嘴部是否异常,尝试提供喜欢的食物,超过24小时请就医",
                "medium"));

        symptomRepository.save(createSymptom("嗉囊肿大",
                "嗉囊部位明显鼓起，触感硬或软",
                "嗉囊炎,消化不良,异物堵塞,细菌感染",
                "暂停喂食观察,轻柔按摩帮助消化,保持温暖,建议尽快就医",
                "high"));

        symptomRepository.save(createSymptom("呼吸急促",
                "呼吸频率加快，张嘴呼吸",
                "呼吸道感染,环境闷热,惊吓应激,心脏问题",
                "保持通风,降低环境温度,减少惊扰,紧急就医",
                "high"));

        symptomRepository.save(createSymptom("粪便异常",
                "粪便颜色、形态或气味异常",
                "消化问题,饮食变化,肠道感染,肝脏问题",
                "记录粪便变化,检查近期饮食,保持饮水清洁,持续异常请就医",
                "medium"));

        symptomRepository.save(createSymptom("眼睛异常",
                "眼睛红肿、流泪或有分泌物",
                "眼部感染,维生素A缺乏,异物刺激,结膜炎",
                "用生理盐水清洁,补充维生素A,检查笼内是否有刺激物,建议就医",
                "medium"));

        symptomRepository.save(createSymptom("脚部问题",
                "脚趾肿胀、脱皮或站立困难",
                "脚气病,栖杆不当,缺乏运动,痛风",
                "更换合适粗细的栖杆,保持笼底清洁,检查饮食是否均衡,严重时就医",
                "low"));

        log.info("症状数据初始化完成");
    }

    private Symptom createSymptom(String name, String description, String causes,
                                  String suggestions, String severity) {
        Symptom symptom = new Symptom();
        symptom.setName(name);
        symptom.setDescription(description);
        symptom.setPossibleCauses(causes);
        symptom.setSuggestions(suggestions);
        symptom.setSeverity(severity);
        return symptom;
    }

    private void initColorGenes() {
        if (colorGeneRepository.count() > 0) {
            log.info("羽色基因数据已存在，跳过初始化");
            return;
        }

        log.info("初始化羽色基因数据...");

        colorGeneRepository.save(createColorGene("绿色（原始）", "GG", "#228B22", true,
                "牡丹鹦鹉的原始野生色，为显性基因"));
        colorGeneRepository.save(createColorGene("黄化", "yy", "#FFD700", false,
                "缺乏黑色素，呈现黄色，隐性基因"));
        colorGeneRepository.save(createColorGene("蓝化", "bb", "#4169E1", false,
                "缺乏黄色素，呈现蓝色，隐性基因"));
        colorGeneRepository.save(createColorGene("白化", "aa", "#F5F5F5", false,
                "同时缺乏黑色素和黄色素，隐性基因"));
        colorGeneRepository.save(createColorGene("紫罗兰", "vv", "#9370DB", false,
                "特殊的蓝色变异，带紫色调"));
        colorGeneRepository.save(createColorGene("橙脸", "of", "#FF8C00", true,
                "面部呈橙色，部分显性"));
        colorGeneRepository.save(createColorGene("桃脸", "pf", "#FFB6C1", true,
                "面部呈粉红色，原始桃脸牡丹特征"));
        colorGeneRepository.save(createColorGene("深绿", "DD", "#006400", true,
                "深色因子，使颜色加深"));

        log.info("羽色基因数据初始化完成");
    }

    private ColorGene createColorGene(String name, String code, String displayColor,
                                      boolean isDominant, String description) {
        ColorGene gene = new ColorGene();
        gene.setName(name);
        gene.setCode(code);
        gene.setDisplayColor(displayColor);
        gene.setIsDominant(isDominant);
        gene.setDescription(description);
        return gene;
    }
}
