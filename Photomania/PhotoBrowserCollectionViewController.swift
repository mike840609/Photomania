//
//  PhotoBrowserCollectionViewController.swift
//  Photomania
//
//  Created by Essan Parto on 2014-08-20.
//  Copyright (c) 2014 Essan Parto. All rights reserved.
//

import UIKit
import Alamofire

class PhotoBrowserCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    //無序、元素不重複
    var photos = Set<PhotoInfo>()
    
    let refreshControl = UIRefreshControl()
    
    // 紀錄是否更新照片 以及正在瀏覽的頁面
    var populatingPhotos = false
    var currentPage = 1
    
    let PhotoBrowserCellIdentifier = "PhotoBrowserCell"
    let PhotoBrowserFooterViewIdentifier = "PhotoBrowserFooterView"
    
    // MARK: Life-cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        
        populatePhotos()
        
        
        
    }
    
    
    // 1.滾動超過80% 載入圖片
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y + view.frame.size.height > scrollView.contentSize.height * 0.8{
            populatePhotos()
        }
    }
    
    func populatePhotos(){
        
        // 2.populatePhotos()方法在currentPage中載入 使用 populatingPhotos 當作標記防止還在載入頁面時載入下一個頁面
        if populatingPhotos {
            return
        }
        
        populatingPhotos = true

        
        // 3.使用創建的路由,只需要將頁數傳遞過去,將返回該頁面的URL字串,api每次大約返回50張,為下一批顯示的照片需要重新呼叫路由
        Alamofire.request(Five100px.Router.PopularPhotos(self.currentPage)).responseJSON { (response) -> Void in
            
            func failed(){self.populatingPhotos = false}
            
            guard let JSON = response.result.value else{failed(); return}
            
            if response.result.error != nil {failed() ; return}
            
            // 4. .responseJSON 後面的程式碼 completion handler(完成處理方法)必須在主線成上面運行,若有其他工作在運行需要用GCD調用到其他列隊,這裡用DISPATCH_QUEUE_PRIORITY_HIGH,來運行操作
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)){
                
                // 5.將JSON數據中的 photos 對應的 value 取出
                guard let photoJsons = JSON.valueForKey("photos") as? [NSDictionary] else {return}
                
                // 6.再添加新的照片時儲存圖片當前的數量
                let lastItem = self.photos.count
                
                // 7.foreach 函數去run photosJsons 字典數組 , 篩選掉nsfw(not safe dor work)圖片,並將 photoinfo(five500.px中定義) 加到 photos 集合中,自定義的類別中改寫 isEqual 以及 hash 方法,這兩個方法都用 id 來比較,因此排序和唯一話photoinfo 對象仍是一個較快的操作
                photoJsons.forEach{
                    
                    guard let nsfw = $0["nsfw"] as? Bool,
                        let id = $0["id"] as? Int,
                        let url = $0["image_url"] as? String
                        where nsfw == false else { return }
                    
                    // 8.如果有人上傳新圖片,所獲得新的一批照片可能包含部分已經下載的照片,這就是為何定義集合Set<photoinfo>,集合內的項目必須要唯一,重複圖片不再次出現
                    self.photos.insert(PhotoInfo(id: id, url:url))
                }
                
                // 9.創建一個 NSIndexPath 是數組 並將其插入到collectionView
                let indexPaths = (lastItem..<self.photos.count).map {NSIndexPath(forItem: $0, inSection: 0)}
                
                // 10.在主執行緒上將集合試圖插入項目,因為UIKit操作都要在主執行緒上
                dispatch_async(dispatch_get_main_queue()){
                    self.collectionView!.insertItemsAtIndexPaths(indexPaths)
                }
                
                self.currentPage++
            }
            
        }
        
        self.populatingPhotos = false
    }
    
    // MARK: CollectionView
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoBrowserCellIdentifier, forIndexPath: indexPath) as! PhotoBrowserCollectionViewCell
        
        
        
        // 設定Cell
        let imageURL = self.photos[self.photos.startIndex.advancedBy(indexPath.item)].url
        cell.imageView.image = nil
        cell.request?.cancel()
        
        cell.request = Alamofire.request(.GET,imageURL).responseImage{
            
            response in
            
            guard let image = response.result.value where response.result.error == nil else{return}
            
            cell.imageView.image = image
            
        }
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: PhotoBrowserFooterViewIdentifier, forIndexPath: indexPath) as UICollectionReusableView
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        performSegueWithIdentifier("ShowPhoto", sender: self.photos[self.photos.startIndex.advancedBy(indexPath.item)].id)
    }
    
    // MARK: Helper
    
    func setupView() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        let layout = UICollectionViewFlowLayout()
        let itemWidth = (view.bounds.size.width - 2) / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = 1.0
        layout.minimumLineSpacing = 1.0
        layout.footerReferenceSize = CGSize(width: collectionView!.bounds.size.width, height: 100.0)
        
        collectionView!.collectionViewLayout = layout
        
        let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 60.0, height: 30.0))
        titleLabel.text = "Photomania"
        titleLabel.textColor = UIColor.whiteColor()
        titleLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        navigationItem.titleView = titleLabel
        
        collectionView?.registerClass(PhotoBrowserCollectionViewCell.classForCoder(), forCellWithReuseIdentifier: PhotoBrowserCellIdentifier)
        collectionView?.registerClass(PhotoBrowserCollectionViewLoadingCell.classForCoder(), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: PhotoBrowserFooterViewIdentifier)
        
        refreshControl.tintColor = UIColor.whiteColor()
        refreshControl.addTarget(self, action: "handleRefresh", forControlEvents: .ValueChanged)
        collectionView!.addSubview(refreshControl)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowPhoto" {
            (segue.destinationViewController as! PhotoViewerViewController).photoID = sender!.integerValue
            (segue.destinationViewController as! PhotoViewerViewController).hidesBottomBarWhenPushed = true
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func handleRefresh() {
        
    }
}

class PhotoBrowserCollectionViewCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    var request:Alamofire.Request?      //用此屬性來儲存Alamofire得請求來載入圖片
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        imageView.frame = bounds
        addSubview(imageView)
    }
}

class PhotoBrowserCollectionViewLoadingCell: UICollectionReusableView {
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        spinner.startAnimating()
        spinner.center = self.center
        addSubview(spinner)
    }
}
